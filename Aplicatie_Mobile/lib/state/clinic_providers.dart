import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/clinic_repository.dart';
import '../data/demo_clinic.dart';
import '../data/medications.dart';
import '../services/history_stats.dart';
import 'providers.dart';
import 'reminder_providers.dart';

final clinicProvider = Provider<ClinicRepository>(
  (ref) => DemoClinic(ref.watch(databaseProvider), threshold: ref.watch(settingsProvider.select((s) => s.alertThreshold))),
);

/// Cardurile din lista medicului, cei de urmărit primii.
final patientSummariesProvider = FutureProvider.autoDispose<List<PatientSummary>>((ref) async {
  // O sesiune nouă sau o doză bifată pe telefon apare imediat la Ion Popescu.
  ref.watch(historyProvider);
  ref.watch(medsVersionProvider);
  final clinic = ref.watch(clinicProvider);
  final now = DateTime.now();
  final from = DateTime(now.year, now.month, now.day - 20);
  final to = DateTime(now.year, now.month, now.day + 1);
  final out = <PatientSummary>[];
  for (final p in await clinic.patients()) {
    out.add(
      summarize(
        await clinic.record(p.id, from: from, to: to),
        now: now,
      ),
    );
  }
  out.sort((a, b) {
    if (a.needsAttention != b.needsAttention) return a.needsAttention ? -1 : 1;
    return a.patient.name.compareTo(b.patient.name);
  });
  return out;
});

/// Ce vede medicul la un pacient pe ultimele [days] zile.
class PatientDetail {
  const PatientDetail({required this.record, required this.stats, required this.adherence, required this.insights, required this.days});
  final PatientRecord record;
  final PeriodStats stats;
  final int? adherence;
  final List<String> insights;
  final int days;
}

Future<PatientDetail> loadPatientDetail(ClinicRepository clinic, String id, int days, {DateTime? now}) async {
  final t = now ?? DateTime.now();
  final today = DateTime(t.year, t.month, t.day);
  final start = DateTime(today.year, today.month, today.day - days + 1);
  final prevStart = DateTime(start.year, start.month, start.day - days);
  final end = DateTime(today.year, today.month, today.day + 1);
  final r = await clinic.record(id, from: prevStart, to: end);
  final current = r.between(start, end);
  final stats = rollingStats(
    days: days,
    samples: current,
    previous: r.between(prevStart, start),
    sessions: r.sessions,
    threshold: r.patient.threshold,
    now: t,
  );
  return PatientDetail(
    record: r,
    stats: stats,
    adherence: adherence(meds: r.meds, intakes: r.intakes, from: start, to: end, now: t),
    insights: [?morningEveningInsight(current), ?afterDoseInsight(current, r.intakes)],
    days: days,
  );
}

final patientDetailProvider = FutureProvider.autoDispose.family<PatientDetail, (String, int)>((ref, key) async {
  ref.watch(historyProvider);
  ref.watch(medsVersionProvider);
  return loadPatientDetail(ref.watch(clinicProvider), key.$1, key.$2);
});
