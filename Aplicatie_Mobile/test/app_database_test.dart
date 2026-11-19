import 'package:flutter_test/flutter_test.dart';
import 'package:manusa_app/core/contract.dart';
import 'package:manusa_app/data/db/app_database.dart';
import 'package:manusa_app/data/db/models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late AppDatabase db;

  setUpAll(sqfliteFfiInit);
  setUp(() async => db = await AppDatabase.open(inMemoryDatabasePath, factory: databaseFactoryFfi));
  tearDown(() => db.close());

  SampleRecord sample(DateTime t, double freq, int index, HandState state) =>
      SampleRecord(at: t, frequency: freq, rms: index * 0.3, index: index, state: state, fingers: const [10, 20, 30, 40, null]);

  test('o sesiune salvată are rezumatul corect', () async {
    final t0 = DateTime(2026, 11, 19, 9);
    final id = await db.startSession(at: t0, activity: HandState.rest, simulated: false);
    await db.addSamples(id, [
      sample(t0, 0, 20, HandState.rest),
      sample(t0.add(const Duration(seconds: 1)), 4.0, 60, HandState.rest),
      sample(t0.add(const Duration(seconds: 2)), 5.0, 70, HandState.posture),
    ]);
    await db.addEvent(id, EventRecord(at: t0, kind: EventKind.alert));
    await db.addEvent(id, EventRecord(at: t0, kind: EventKind.mark));
    final s = await db.finishSession(id, at: t0.add(const Duration(minutes: 3)));

    expect(s.avgFrequency, closeTo(4.5, 1e-9)); // secunda fără tremor nu intră în medie
    expect(s.avgIndex, 50);
    expect(s.maxIndex, 70);
    expect(s.alertCount, 1);
    expect(s.activity, HandState.rest);
    expect(s.duration, const Duration(minutes: 3));
    expect((await db.samples(id)).last.fingers, [10, 20, 30, 40, null]);
  });

  test('sesiunile simulate nu apar în istoricul real', () async {
    final t0 = DateTime(2026, 11, 19, 9);
    final real = await db.startSession(at: t0, activity: HandState.rest, simulated: false);
    final demo = await db.startSession(at: t0, activity: HandState.rest, simulated: true);
    await db.finishSession(real, at: t0);
    await db.finishSession(demo, at: t0);
    await db.startSession(at: t0, activity: HandState.rest, simulated: false); // neîncheiată

    expect((await db.sessions(simulated: false)).map((s) => s.id), [real]);
    expect((await db.sessions(simulated: true)).map((s) => s.id), [demo]);
  });

  test('ștergerea unei sesiuni șterge și eșantioanele', () async {
    final t0 = DateTime(2026, 11, 19, 9);
    final id = await db.startSession(at: t0, activity: HandState.rest, simulated: false);
    await db.addSamples(id, [sample(t0, 4, 40, HandState.rest)]);
    await db.deleteSession(id);
    expect(await db.samples(id), isEmpty);
  });
}
