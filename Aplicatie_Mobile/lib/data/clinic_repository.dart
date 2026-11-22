import '../core/tests.dart';
import '../services/history_stats.dart';
import 'db/app_database.dart';
import 'db/models.dart';
import 'medication_repository.dart';
import 'medications.dart';

/// Un pacient al medicului.
class ClinicPatient {
  const ClinicPatient({
    required this.id,
    required this.name,
    required this.age,
    required this.diagnosis,
    this.threshold = 60,
    this.local = false,
  });
  final String id;
  final String name;
  final int age;
  final String diagnosis;
  final int threshold;

  /// Datele vin de pe acest telefon (Ion Popescu), nu din clinica demo.
  final bool local;

  String get initials => name.split(' ').where((w) => w.isNotEmpty).take(2).map((w) => w[0]).join().toUpperCase();
  String get details => '$age ani · $diagnosis';
}

/// Tot ce are medicul despre un pacient într-un interval.
class PatientRecord {
  const PatientRecord({
    required this.patient,
    required this.samples,
    required this.sessions,
    required this.tapping,
    required this.meds,
    required this.intakes,
  });
  final ClinicPatient patient;

  /// Eșantioanele intervalului (nu neapărat câte unul pe secundă la pacienții demo).
  final List<SampleRecord> samples;
  final List<SessionRecord> sessions;

  /// Atingeri pe secundă la testele de tapping, în ordine cronologică.
  final List<double> tapping;
  final List<Medication> meds;
  final List<Intake> intakes;

  List<SampleRecord> between(DateTime from, DateTime to) => [
    for (final s in samples)
      if (!s.at.isBefore(from) && s.at.isBefore(to)) s,
  ];
}

/// Unde citește medicul. Acum: [DemoClinic]. Cu Supabase: o implementare care citește din server.
abstract class ClinicRepository {
  Future<List<ClinicPatient>> patients();
  Future<PatientRecord> record(String patientId, {required DateTime from, required DateTime to});
}

/// Rezumatul de pe cardul pacientului: tendința pe 7 zile și de ce trebuie urmărit.
class PatientSummary {
  const PatientSummary({
    required this.patient,
    required this.daily,
    required this.mean7,
    required this.delta7,
    required this.alertsToday,
    required this.adherence7,
    required this.lastData,
    required this.reasons,
  });
  final ClinicPatient patient;

  /// Media pe zi în ultimele 14 zile (null = fără date).
  final List<double?> daily;
  final double? mean7;
  final int? delta7;
  final int alertsToday;
  final int? adherence7;
  final DateTime? lastData;
  final List<String> reasons;

  bool get needsAttention => reasons.isNotEmpty;
}

/// De ce e un pacient „de urmărit”: peste prag azi, tremor în creștere, aderență mică, fără date.
PatientSummary summarize(PatientRecord r, {required DateTime now}) {
  final today = DateTime(now.year, now.month, now.day);
  final weekAgo = today.subtract(const Duration(days: 6));
  final stats = rollingStats(
    days: 7,
    samples: r.between(weekAgo, now.add(const Duration(days: 1))),
    previous: r.between(weekAgo.subtract(const Duration(days: 7)), weekAgo),
    sessions: r.sessions,
    threshold: r.patient.threshold,
    now: now,
  );
  final todaySessions = r.sessions.where((s) => !s.startedAt.isBefore(today));
  final alertsToday = todaySessions.fold<int>(0, (a, s) => a + s.alertCount);
  final adh = adherence(meds: r.meds, intakes: r.intakes, from: weekAgo, to: now, now: now);
  DateTime? last;
  for (final s in r.samples) {
    if (last == null || s.at.isAfter(last)) last = s.at;
  }
  final reasons = <String>[
    if (alertsToday >= 2) 'peste prag de $alertsToday ori azi',
    if ((stats.deltaPercent ?? 0) >= 10) 'tremor în creștere: +${stats.deltaPercent} % în 7 zile',
    if (adh != null && adh < 85) 'aderență $adh %',
    if (last == null)
      'fără date încă'
    else if (today.difference(DateTime(last.year, last.month, last.day)).inDays >= 3)
      'fără date de ${today.difference(DateTime(last.year, last.month, last.day)).inDays} zile',
  ];
  return PatientSummary(
    patient: r.patient,
    daily: dailyMeans(r.samples, days: 14, now: now),
    mean7: stats.mean,
    delta7: stats.deltaPercent,
    alertsToday: alertsToday,
    adherence7: adh,
    lastData: last,
    reasons: reasons,
  );
}

/// Pacientul de pe acest telefon: sesiunile, testele și medicamentele lui Ion Popescu.
const localPatient = ClinicPatient(id: AppDatabase.localPatient, name: 'Ion Popescu', age: 68, diagnosis: 'boala Parkinson', local: true);

/// Citește datele lui Ion din baza locală: întâi cele reale; dacă nu are, pe cele demo (simulate).
Future<PatientRecord> localRecord(AppDatabase db, {required DateTime from, required DateTime to, int threshold = 60}) async {
  var samples = await db.samplesBetween(from, to, simulated: false);
  var simulated = false;
  if (samples.isEmpty) {
    samples = await db.samplesBetween(from, to, simulated: true);
    simulated = samples.isNotEmpty;
  }
  final sessions = (await db.sessions(simulated: simulated, since: from)).where((s) => s.startedAt.isBefore(to)).toList();
  final taps = (await db.resultsOf(TestKind.tappingGlove.id, simulated: simulated, limit: 30)).reversed.map((r) => r.value).toList();
  final repo = MedicationRepository(db.raw);
  return PatientRecord(
    patient: ClinicPatient(
      id: localPatient.id,
      name: localPatient.name,
      age: localPatient.age,
      diagnosis: localPatient.diagnosis,
      threshold: threshold,
      local: true,
    ),
    samples: samples,
    sessions: sessions,
    tapping: taps,
    meds: await repo.medications(),
    intakes: await repo.intakesBetween(from, to),
  );
}
