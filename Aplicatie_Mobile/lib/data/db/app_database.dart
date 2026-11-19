import 'package:sqflite/sqflite.dart';

import '../../core/contract.dart';
import 'models.dart';

/// Baza de date de pe telefon. Datele nu pleacă de aici decât când utilizatorul trimite un raport.
class AppDatabase {
  AppDatabase._(this._db);

  final Database _db;

  static const _version = 1;

  /// [path] poate fi `inMemoryDatabasePath`, pentru teste.
  static Future<AppDatabase> open(String path, {DatabaseFactory? factory}) async {
    final f = factory ?? databaseFactory;
    final db = await f.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: _version,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
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
        },
      ),
    );
    return AppDatabase._(db);
  }

  Future<int> startSession({required DateTime at, required HandState activity, required bool simulated}) =>
      _db.insert('sessions', {'started_at': at.millisecondsSinceEpoch, 'activity': activity.code, 'simulated': simulated ? 1 : 0});

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
