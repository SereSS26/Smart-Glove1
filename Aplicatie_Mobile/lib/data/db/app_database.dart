import 'package:sqflite/sqflite.dart';

import '../../core/contract.dart';
import 'models.dart';

/// Baza de date de pe telefon. Datele nu pleacă de aici decât când utilizatorul trimite un raport.
class AppDatabase {
  AppDatabase._(this._db);

  final Database _db;

  static const _version = 2;

  /// Pacientul de pe acest telefon (contul demo); sesiunile vechi îi aparțin lui.
  static const localPatient = 'p-ion';

  /// [path] poate fi `inMemoryDatabasePath`, pentru teste.
  static Future<AppDatabase> open(String path, {DatabaseFactory? factory}) async {
    final f = factory ?? databaseFactory;
    final db = await f.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: _version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onUpgrade: (db, from, to) async {
          if (from < 2) await _upgradeTo2(db);
        },
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE sessions (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              started_at INTEGER NOT NULL,
              ended_at INTEGER,
              activity INTEGER NOT NULL,
              note TEXT NOT NULL DEFAULT '',
              avg_freq REAL,
              avg_index INTEGER NOT NULL DEFAULT 0,
              max_index INTEGER NOT NULL DEFAULT 0,
              alert_count INTEGER NOT NULL DEFAULT 0,
              simulated INTEGER NOT NULL
            )''');
          await db.execute('''
            CREATE TABLE samples (
              session_id INTEGER NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
              t INTEGER NOT NULL,
              freq REAL NOT NULL, rms REAL NOT NULL, idx INTEGER NOT NULL, state INTEGER NOT NULL,
              f1 INTEGER, f2 INTEGER, f3 INTEGER, f4 INTEGER, f5 INTEGER
            )''');
          await db.execute('''
            CREATE TABLE events (
              session_id INTEGER NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
              t INTEGER NOT NULL,
              kind TEXT NOT NULL,
              text TEXT NOT NULL DEFAULT ''
            )''');
          await db.execute('CREATE INDEX samples_session ON samples(session_id, t)');
          await db.execute('CREATE INDEX events_session ON events(session_id, t)');
          await _upgradeTo2(db);
        },
      ),
    );
    return AppDatabase._(db);
  }

  /// Versiunea 2: al cui e fiecare sesiune, felul ei (liberă / evaluare / test), rezultatele testelor,
  /// medicamentele, dozele, stocul și reminderele.
  static Future<void> _upgradeTo2(Database db) async {
    await db.execute("ALTER TABLE sessions ADD COLUMN user_id TEXT NOT NULL DEFAULT '$localPatient'");
    await db.execute("ALTER TABLE sessions ADD COLUMN kind TEXT NOT NULL DEFAULT 'free'");
    await db.execute('''
      CREATE TABLE test_results (
        session_id INTEGER NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
        test TEXT NOT NULL,
        started_at INTEGER NOT NULL,
        ended_at INTEGER NOT NULL,
        value REAL NOT NULL,
        metrics TEXT NOT NULL DEFAULT '{}',
        trace TEXT NOT NULL DEFAULT '[]'
      )''');
    await db.execute('CREATE INDEX test_results_session ON test_results(session_id)');
    await db.execute('''
      CREATE TABLE medications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        strength TEXT NOT NULL DEFAULT '',
        form TEXT NOT NULL DEFAULT 'comprimat',
        dose REAL NOT NULL DEFAULT 1,
        times TEXT NOT NULL DEFAULT '[]',
        stock REAL NOT NULL DEFAULT 0,
        pack_size INTEGER NOT NULL DEFAULT 30,
        warn_days INTEGER NOT NULL DEFAULT 5,
        color INTEGER NOT NULL,
        shape TEXT NOT NULL DEFAULT 'round',
        note TEXT NOT NULL DEFAULT '',
        active INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE intakes (
        med_id INTEGER NOT NULL REFERENCES medications(id) ON DELETE CASCADE,
        scheduled_at INTEGER NOT NULL,
        status TEXT NOT NULL,
        taken_at INTEGER,
        PRIMARY KEY (med_id, scheduled_at)
      )''');
    await db.execute('''
      CREATE TABLE stock_events (
        med_id INTEGER NOT NULL REFERENCES medications(id) ON DELETE CASCADE,
        t INTEGER NOT NULL,
        delta REAL NOT NULL,
        reason TEXT NOT NULL
      )''');
    await db.execute('''
      CREATE TABLE reminders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        kind TEXT NOT NULL,
        title TEXT NOT NULL,
        time TEXT NOT NULL,
        days TEXT NOT NULL DEFAULT '[1,2,3,4,5,6,7]',
        enabled INTEGER NOT NULL DEFAULT 1
      )''');
  }

  /// Baza de date brută, pentru depozitele care adaugă tabele (medicamente, remindere).
  Database get raw => _db;

  Future<int> startSession({
    required DateTime at,
    required HandState activity,
    required bool simulated,
    SessionKind kind = SessionKind.free,
    String userId = localPatient,
  }) => _db.insert('sessions', {
    'started_at': at.millisecondsSinceEpoch,
    'activity': activity.code,
    'simulated': simulated ? 1 : 0,
    'kind': kind.name,
    'user_id': userId,
  });

  Future<void> addTestResult(int sessionId, TestResultRecord r) => _db.insert('test_results', r.toRow(sessionId));

  Future<List<TestResultRecord>> testResults(int sessionId) async {
    final rows = await _db.query('test_results', where: 'session_id = ?', whereArgs: [sessionId], orderBy: 'started_at');
    return rows.map(TestResultRecord.fromRow).toList();
  }

  /// Rezultatele unui test în timp (cele mai noi primele), pentru comparații și grafice.
  Future<List<TestResultRecord>> resultsOf(String test, {required bool simulated, int limit = 30}) async {
    final rows = await _db.rawQuery(
      '''SELECT r.* FROM test_results r JOIN sessions s ON s.id = r.session_id
         WHERE r.test = ? AND s.simulated = ? AND s.ended_at IS NOT NULL ORDER BY r.started_at DESC LIMIT ?''',
      [test, simulated ? 1 : 0, limit],
    );
    return rows.map(TestResultRecord.fromRow).toList();
  }

  /// Eșantioanele unei perioade (pentru sumele pe zi, săptămână, lună).
  Future<List<SampleRecord>> samplesBetween(DateTime from, DateTime to, {required bool simulated}) async {
    final rows = await _db.rawQuery(
      '''SELECT x.* FROM samples x JOIN sessions s ON s.id = x.session_id
         WHERE s.simulated = ? AND s.ended_at IS NOT NULL AND x.t >= ? AND x.t < ? ORDER BY x.t''',
      [simulated ? 1 : 0, from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
    );
    return rows.map(SampleRecord.fromRow).toList();
  }

  Future<void> addSamples(int sessionId, List<SampleRecord> samples) async {
    final batch = _db.batch();
    for (final s in samples) {
      batch.insert('samples', s.toRow(sessionId));
    }
    await batch.commit(noResult: true);
  }

  Future<void> addEvent(int sessionId, EventRecord e) =>
      _db.insert('events', {'session_id': sessionId, 't': e.at.millisecondsSinceEpoch, 'kind': e.kind.name, 'text': e.text});

  Future<void> setNote(int sessionId, String note) => _db.update('sessions', {'note': note}, where: 'id = ?', whereArgs: [sessionId]);

  /// Închide sesiunea și calculează rezumatul din eșantioane și evenimente.
  Future<SessionRecord> finishSession(int sessionId, {required DateTime at}) async {
    final stats = (await _db.rawQuery(
      '''
      SELECT AVG(CASE WHEN freq > 0 THEN freq END) AS avg_freq,
             COALESCE(ROUND(AVG(idx)), 0) AS avg_index,
             COALESCE(MAX(idx), 0) AS max_index
      FROM samples WHERE session_id = ?''',
      [sessionId],
    )).first;
    final activity = (await _db.rawQuery('SELECT state FROM samples WHERE session_id = ? GROUP BY state ORDER BY COUNT(*) DESC LIMIT 1', [
      sessionId,
    ]));
    final alerts =
        Sqflite.firstIntValue(await _db.rawQuery("SELECT COUNT(*) FROM events WHERE session_id = ? AND kind = 'alert'", [sessionId])) ?? 0;
    await _db.update(
      'sessions',
      {
        'ended_at': at.millisecondsSinceEpoch,
        'avg_freq': stats['avg_freq'],
        'avg_index': (stats['avg_index']! as num).toInt(),
        'max_index': (stats['max_index']! as num).toInt(),
        'alert_count': alerts,
        if (activity.isNotEmpty) 'activity': activity.first['state'],
      },
      where: 'id = ?',
      whereArgs: [sessionId],
    );
    return (await session(sessionId))!;
  }

  Future<SessionRecord?> session(int id) async {
    final rows = await _db.query('sessions', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : SessionRecord.fromRow(rows.first);
  }

  /// Sesiunile încheiate, cele mai noi primele. Sesiunile simulate și cele reale nu se amestecă.
  Future<List<SessionRecord>> sessions({required bool simulated, DateTime? since, int limit = 200}) async {
    final rows = await _db.query(
      'sessions',
      where: 'ended_at IS NOT NULL AND simulated = ?${since != null ? ' AND started_at >= ?' : ''}',
      whereArgs: [simulated ? 1 : 0, if (since != null) since.millisecondsSinceEpoch],
      orderBy: 'started_at DESC',
      limit: limit,
    );
    return rows.map(SessionRecord.fromRow).toList();
  }

  Future<List<SampleRecord>> samples(int sessionId) async {
    final rows = await _db.query('samples', where: 'session_id = ?', whereArgs: [sessionId], orderBy: 't');
    return rows.map(SampleRecord.fromRow).toList();
  }

  Future<List<EventRecord>> events(int sessionId) async {
    final rows = await _db.query('events', where: 'session_id = ?', whereArgs: [sessionId], orderBy: 't');
    return rows.map(EventRecord.fromRow).toList();
  }

  Future<void> deleteSession(int id) => _db.delete('sessions', where: 'id = ?', whereArgs: [id]);

  /// Șterge sesiunile rămase deschise (de ex. aplicația a fost închisă în timpul înregistrării).
  Future<void> deleteUnfinished() => _db.delete('sessions', where: 'ended_at IS NULL');

  Future<void> close() => _db.close();
}
