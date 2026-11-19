import 'dart:math';

import '../core/contract.dart';
import '../services/alert_monitor.dart';
import 'db/app_database.dart';
import 'db/models.dart';

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
