import 'package:flutter_test/flutter_test.dart';
import 'package:manusa_app/core/contract.dart';
import 'package:manusa_app/data/db/app_database.dart';
import 'package:manusa_app/data/db/models.dart';
import 'package:manusa_app/data/demo_seed.dart';
import 'package:manusa_app/services/export_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('CSV-ul are antet și un rând pe eșantion, cu virgulă zecimală', () {
    final t0 = DateTime(2026, 11, 19, 9);
    final s = SessionRecord(
      id: 1,
      startedAt: t0,
      endedAt: t0.add(const Duration(seconds: 2)),
      activity: HandState.rest,
      note: '',
      avgFrequency: 4.6,
      avgIndex: 50,
      maxIndex: 60,
      alertCount: 0,
      simulated: false,
    );
    final csv = ExportService.buildCsv(s, [
      SampleRecord(at: t0, frequency: 4.6, rms: 12.5, index: 50, state: HandState.rest, fingers: const [1, 2, 3, 4, null]),
      SampleRecord(
        at: t0.add(const Duration(seconds: 1)),
        frequency: 0,
        rms: 3,
        index: 20,
        state: HandState.action,
        fingers: const [5, 6, 7, 8, 9],
      ),
    ]);
    final lines = csv.split('\n');
    expect(lines, hasLength(3));
    expect(lines[0], startsWith('timp;secunda;frecventa_hz'));
    expect(lines[1], contains(';0;4,60;12,50;50;repaus;1;2;3;4;'));
    expect(lines[2], contains(';1;0,00;3,00;20;acțiune;5;6;7;8;9'));
  });

  test('datele demo umplu o săptămână de sesiuni simulate', () async {
    final db = await AppDatabase.open(inMemoryDatabasePath, factory: databaseFactoryFfi);
    final now = DateTime(2026, 11, 19, 22);
    final n = await addDemoWeek(db, threshold: 60, now: now);
    expect(n, 14);
    final sessions = await db.sessions(simulated: true);
    expect(sessions, hasLength(14));
    expect(await db.sessions(simulated: false), isEmpty);
    expect(sessions.every((s) => s.avgIndex > 0 && s.endedAt != null), isTrue);
    await db.close();
  });
}
