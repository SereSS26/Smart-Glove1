import 'package:sqflite/sqflite.dart';

import 'db/app_database.dart';
import 'medications.dart';

/// Medicamentele, dozele, stocul și reminderele unui pacient, în baza locală (v2).
/// Primește baza brută, ca să meargă și din notificări, cu aplicația închisă.
class MedicationRepository {
  MedicationRepository(this._db, {this.userId = AppDatabase.localPatient});

  final Database _db;
  final String userId;

  Future<List<Medication>> medications({bool activeOnly = true}) async {
    final rows = await _db.query(
      'medications',
      where: activeOnly ? 'user_id = ? AND active = 1' : 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'name COLLATE NOCASE',
    );
    return rows.map(Medication.fromRow).toList();
  }

  Future<Medication?> medication(int id) async {
    final rows = await _db.query('medications', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Medication.fromRow(rows.first);
  }

  /// Adaugă sau actualizează; întoarce medicamentul cu id.
  Future<Medication> save(Medication m) async {
    if (m.id == null) {
      final id = await _db.insert('medications', m.toRow());
      return m.copyWith(id: id);
    }
    await _db.update('medications', m.toRow(), where: 'id = ?', whereArgs: [m.id]);
    return m;
  }

  /// Mai multe deodată (după scanarea rețetei), într-o singură tranzacție.
  Future<List<Medication>> saveAll(List<Medication> meds) => _db.transaction((tx) async {
    final out = <Medication>[];
    for (final m in meds) {
      out.add(m.copyWith(id: await tx.insert('medications', m.toRow())));
    }
    return out;
  });

  Future<void> delete(int id) => _db.delete('medications', where: 'id = ?', whereArgs: [id]);

  Future<List<Intake>> intakesBetween(DateTime from, DateTime to) async {
    final rows = await _db.rawQuery(
      'SELECT i.* FROM intakes i JOIN medications m ON m.id = i.med_id '
      'WHERE m.user_id = ? AND i.scheduled_at >= ? AND i.scheduled_at < ?',
      [userId, from.millisecondsSinceEpoch, to.millisecondsSinceEpoch],
    );
    return rows.map(Intake.fromRow).toList();
  }

  /// Bifează doza ca luată și o scade din stoc. De două ori la rând nu scade de două ori.
  Future<bool> markTaken(int medId, DateTime scheduledAt, {DateTime? at}) => _db.transaction((tx) async {
    final key = [medId, scheduledAt.millisecondsSinceEpoch];
    final existing = await tx.query('intakes', where: 'med_id = ? AND scheduled_at = ?', whereArgs: key);
    if (existing.isNotEmpty && existing.first['status'] == IntakeStatus.taken.name) return false;
    final med = await tx.query('medications', columns: ['dose'], where: 'id = ?', whereArgs: [medId]);
    if (med.isEmpty) return false;
    final dose = (med.first['dose'] as num).toDouble();
    final now = at ?? DateTime.now();
    await tx.insert('intakes', {
      'med_id': medId,
      'scheduled_at': scheduledAt.millisecondsSinceEpoch,
      'status': IntakeStatus.taken.name,
      'taken_at': now.millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await tx.rawUpdate('UPDATE medications SET stock = MAX(0, stock - dose) WHERE id = ?', [medId]);
    await tx.insert('stock_events', {'med_id': medId, 't': now.millisecondsSinceEpoch, 'delta': -dose, 'reason': 'taken'});
    return true;
  });

  /// Anulează bifa (și pune doza înapoi în stoc dacă fusese luată).
  Future<void> undo(int medId, DateTime scheduledAt) => _db.transaction((tx) async {
    final key = [medId, scheduledAt.millisecondsSinceEpoch];
    final existing = await tx.query('intakes', where: 'med_id = ? AND scheduled_at = ?', whereArgs: key);
    if (existing.isEmpty) return;
    await tx.delete('intakes', where: 'med_id = ? AND scheduled_at = ?', whereArgs: key);
    if (existing.first['status'] == IntakeStatus.taken.name) {
      await tx.rawUpdate('UPDATE medications SET stock = stock + dose WHERE id = ?', [medId]);
      final med = await tx.query('medications', columns: ['dose'], where: 'id = ?', whereArgs: [medId]);
      await tx.insert('stock_events', {
        'med_id': medId,
        't': DateTime.now().millisecondsSinceEpoch,
        'delta': (med.first['dose'] as num).toDouble(),
        'reason': 'undo',
      });
    }
  });

  /// Amână doza până la [until] (nu atinge stocul).
  Future<void> snooze(int medId, DateTime scheduledAt, DateTime until) => _db.insert('intakes', {
    'med_id': medId,
    'scheduled_at': scheduledAt.millisecondsSinceEpoch,
    'status': IntakeStatus.snoozed.name,
    'taken_at': until.millisecondsSinceEpoch,
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> skip(int medId, DateTime scheduledAt) => _db.insert('intakes', {
    'med_id': medId,
    'scheduled_at': scheduledAt.millisecondsSinceEpoch,
    'status': IntakeStatus.skipped.name,
    'taken_at': DateTime.now().millisecondsSinceEpoch,
  }, conflictAlgorithm: ConflictAlgorithm.replace);

  /// „Am cumpărat”: adaugă [qty] unități în stoc.
  Future<void> addStock(int medId, double qty) => _db.transaction((tx) async {
    await tx.rawUpdate('UPDATE medications SET stock = stock + ? WHERE id = ?', [qty, medId]);
    await tx.insert('stock_events', {'med_id': medId, 't': DateTime.now().millisecondsSinceEpoch, 'delta': qty, 'reason': 'bought'});
  });

  Future<List<ReminderItem>> reminders() async {
    final rows = await _db.query('reminders', where: 'user_id = ?', whereArgs: [userId], orderBy: 'time');
    return rows.map(ReminderItem.fromRow).toList();
  }

  Future<ReminderItem> saveReminder(ReminderItem r) async {
    if (r.id == null) {
      final id = await _db.insert('reminders', r.toRow());
      return ReminderItem.fromRow({...r.toRow(), 'id': id});
    }
    await _db.update('reminders', r.toRow(), where: 'id = ?', whereArgs: [r.id]);
    return r;
  }

  Future<void> deleteReminder(int id) => _db.delete('reminders', where: 'id = ?', whereArgs: [id]);
}
