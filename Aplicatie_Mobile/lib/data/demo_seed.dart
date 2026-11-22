import 'dart:math';

import '../core/contract.dart';
import '../core/tests.dart';
import '../services/alert_monitor.dart';
import 'db/app_database.dart';
import 'db/models.dart';
import 'medication_repository.dart';
import 'medications.dart';

/// Umple Istoricul cu o săptămână de sesiuni simulate, ca să se vadă graficele fără mănușă.
/// Toate sunt marcate simulate și nu apar în istoricul real.
Future<int> addDemoWeek(AppDatabase db, {required int threshold, DateTime? now, int seed = 11}) async {
  final random = Random(seed);
  final today = now ?? DateTime.now();
  var count = 0;
  for (var d = 6; d >= 0; d--) {
    final day = DateTime(today.year, today.month, today.day).subtract(Duration(days: d));
    // Dimineața (după medicament, tremor mai mic) și seara (tremor mai mare).
    for (final (hour, base) in [(9, 32 + random.nextInt(14)), (20, 46 + random.nextInt(16))]) {
      final start = day.add(Duration(hours: hour, minutes: random.nextInt(40)));
      if (start.isAfter(today)) continue;
      final minutes = 6 + random.nextInt(9);
      final activity = HandState.values[random.nextInt(3)];
      final id = await db.startSession(at: start, activity: activity, simulated: true);
      final monitor = AlertMonitor();
      final samples = <SampleRecord>[];
      var index = base.toDouble();
      for (var s = 0; s < minutes * 60; s++) {
        final at = start.add(Duration(seconds: s));
        // Un episod mai puternic la mijlocul sesiunii.
        final burst = (s > minutes * 20 && s < minutes * 20 + 90) ? 24 : 0;
        index += (base + burst - index) * 0.05 + (random.nextDouble() - 0.5) * 4;
        index = index.clamp(0, 100);
        final i = index.round();
        samples.add(
          SampleRecord(
            at: at,
            frequency: i < 25 ? 0 : 4.4 + random.nextDouble() * 0.9,
            rms: i * 0.3,
            index: i,
            state: activity,
            fingers: [for (var f = 0; f < GloveContract.fingerCount; f++) (40 + 30 * sin(s / 20 + f)).round()],
          ),
        );
        if (monitor.onSample(at, i, threshold)) {
          await db.addEvent(id, EventRecord(at: at, kind: EventKind.alert, text: 'indice $i'));
        }
      }
      await db.addSamples(id, samples);
      if (random.nextBool()) await db.setNote(id, hour == 9 ? 'După medicament.' : 'Seara, după cină.');
      await db.finishSession(id, at: start.add(Duration(minutes: minutes)));
      count++;
    }
  }
  return count;
}

/// Umple Istoricul cu [days] zile simulate (implicit 90): dimineața și seara câte o înregistrare,
/// plus evaluarea completă de dimineață (cu cele 4 teste). Tremorul scade ușor în timp, ca să se vadă evoluția.
/// Toate sunt marcate simulate și nu apar în istoricul real. Întoarce câte sesiuni a adăugat.
Future<int> addDemoMonths(AppDatabase db, {required int threshold, int days = 90, DateTime? now, int seed = 21}) async {
  final random = Random(seed);
  final today = now ?? DateTime.now();
  var count = 0;
  for (var d = days - 1; d >= 0; d--) {
    final day = DateTime(today.year, today.month, today.day).subtract(Duration(days: d));
    final trend = 1 - 0.18 * (days - d) / days; // ~18 % mai puțin tremor la final
    if (random.nextDouble() < 0.08) continue; // câteva zile fără date

    Future<void> free(int hour, double base) async {
      final start = day.add(Duration(hours: hour, minutes: random.nextInt(40)));
      if (start.isAfter(today)) return;
      final id = await db.startSession(at: start, activity: HandState.rest, simulated: true);
      final monitor = AlertMonitor();
      final samples = <SampleRecord>[];
      var index = base;
      for (var s = 0; s < 300; s++) {
        final at = start.add(Duration(seconds: s));
        final burst = (s > 120 && s < 170) ? 18 : 0;
        index += (base + burst - index) * 0.06 + (random.nextDouble() - 0.5) * 4;
        index = index.clamp(0, 100);
        final i = index.round();
        samples.add(
          SampleRecord(
            at: at,
            frequency: i < 25 ? 0 : 4.4 + random.nextDouble() * 0.9,
            rms: i * 0.3,
            index: i,
            state: HandState.rest,
            fingers: [for (var f = 0; f < GloveContract.fingerCount; f++) (40 + 30 * sin(s / 20 + f)).round()],
          ),
        );
        if (monitor.onSample(at, i, threshold)) await db.addEvent(id, EventRecord(at: at, kind: EventKind.alert, text: 'indice $i'));
      }
      await db.addSamples(id, samples);
      await db.finishSession(id, at: start.add(const Duration(minutes: 5)));
      count++;
    }

    await free(9, (36 + random.nextInt(10)) * trend);
    await free(20, (50 + random.nextInt(12)) * trend);

    // Evaluarea completă, la 10 dimineața.
    final start = day.add(Duration(hours: 10, minutes: random.nextInt(30)));
    if (start.isAfter(today) || random.nextDouble() < 0.12) continue;
    final id = await db.startSession(at: start, activity: HandState.rest, simulated: true, kind: SessionKind.assessment);
    var t = start;
    for (final test in TestKind.assessment) {
      final testStart = t;
      if (test.isTremor) {
        final base = {TestKind.rest: 40.0, TestKind.postural: 52.0, TestKind.kinetic: 46.0}[test]! * trend + random.nextInt(8) - 4;
        final samples = [
          for (var s = 0; s < test.seconds; s++)
            SampleRecord(
              at: testStart.add(Duration(seconds: s)),
              frequency: 4.5 + random.nextDouble() * 0.7,
              rms: base * 0.3,
              index: (base + (random.nextDouble() - 0.5) * 8).round().clamp(0, 100),
              state: test.state,
              fingers: const [null, null, null, null, null],
            ),
        ];
        await db.addSamples(id, samples);
        final avg = samples.map((x) => x.index).reduce((a, b) => a + b) / samples.length;
        await db.addTestResult(
          id,
          TestResultRecord(
            test: test.id,
            startedAt: testStart,
            endedAt: testStart.add(Duration(seconds: test.seconds)),
            value: avg.roundToDouble(),
            metrics: {'avg': avg.round(), 'max': samples.map((x) => x.index).reduce(max), 'freq': 4.8},
            trace: [for (final x in samples) x.index],
          ),
        );
      } else {
        final rate = 2.6 + 0.6 * (1 - trend) / 0.18 + (random.nextDouble() - 0.5) * 0.3;
        await db.addTestResult(
          id,
          TestResultRecord(
            test: test.id,
            startedAt: testStart,
            endedAt: testStart.add(Duration(seconds: test.seconds)),
            value: double.parse(rate.toStringAsFixed(2)),
            metrics: {
              'taps': (rate * test.seconds).round(),
              'rate': double.parse(rate.toStringAsFixed(2)),
              'amplitude': 70 + random.nextInt(15),
              'regularity': 0.08 + random.nextDouble() * 0.1,
              'fatigue': 0.05 + random.nextDouble() * 0.15,
            },
          ),
        );
      }
      t = t.add(Duration(seconds: test.seconds + 20));
    }
    await db.finishSession(id, at: t);
    count++;
  }
  await addDemoMedications(db, days: days, now: today, seed: seed);
  return count;
}

/// Medicamentele demo ale lui Ion: Madopar de 3 ori pe zi (stoc pe terminate, ca să se vadă avertismentul),
/// Rivotril seara, reminderul de test și dozele din ultimele [days] zile (cam 9 din 10 luate).
/// Nu face nimic dacă pacientul are deja medicamente.
Future<void> addDemoMedications(AppDatabase db, {int days = 90, DateTime? now, int seed = 21}) async {
  final repo = MedicationRepository(db.raw);
  if ((await repo.medications(activeOnly: false)).isNotEmpty) return;
  final random = Random(seed + 1);
  final today = now ?? DateTime.now();
  final since = DateTime(today.year, today.month, today.day).subtract(Duration(days: days));
  final meds = await repo.saveAll([
    Medication(
      name: 'Madopar',
      strength: '250 mg',
      dose: 1,
      times: const ['08:00', '14:00', '21:00'],
      stock: 12,
      packSize: 100,
      color: 0,
      createdAt: since,
    ),
    Medication(
      name: 'Rivotril',
      strength: '0,5 mg',
      dose: 0.5,
      times: const ['22:00'],
      stock: 28,
      packSize: 30,
      color: 4,
      note: 'la culcare',
      createdAt: since,
    ),
  ]);
  await repo.saveReminder(const ReminderItem(kind: ReminderKind.test, title: 'Evaluare completă', time: '10:00'));
  await repo.saveReminder(
    const ReminderItem(kind: ReminderKind.other, title: 'Exerciții pentru mâini', time: '18:00', days: [1, 3, 5], enabled: false),
  );
  final batch = db.raw.batch();
  for (var d = days; d >= 0; d--) {
    final day = DateTime(today.year, today.month, today.day - d);
    for (final m in meds) {
      for (final t in m.times) {
        final at = atTime(day, t);
        if (at.isAfter(today.subtract(const Duration(minutes: 30)))) continue;
        if (random.nextDouble() < 0.09) continue; // doză uitată
        batch.insert('intakes', {
          'med_id': m.id,
          'scheduled_at': at.millisecondsSinceEpoch,
          'status': IntakeStatus.taken.name,
          'taken_at': at.add(Duration(minutes: random.nextInt(25))).millisecondsSinceEpoch,
        });
      }
    }
  }
  await batch.commit(noResult: true);
}
