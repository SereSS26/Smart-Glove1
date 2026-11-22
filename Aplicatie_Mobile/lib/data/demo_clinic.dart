import 'dart:math';

import '../core/contract.dart';
import 'clinic_repository.dart';
import 'db/app_database.dart';
import 'db/models.dart';
import 'medications.dart';

/// Profilul unui pacient fictiv: cum arată tremorul și aderența lui.
class _Profile {
  const _Profile(
    this.patient, {
    required this.base,
    required this.evening,
    this.recentRise = 0,
    this.adherence = 0.93,
    this.silentDays = 0,
    required this.meds,
    this.tapping = 3.0,
  });
  final ClinicPatient patient;
  final double base;
  final double evening;

  /// Cât crește tremorul în ultima săptămână (0,18 = +18 %).
  final double recentRise;
  final double adherence;

  /// Câte zile la rând n-a mai trimis date (până azi).
  final int silentDays;
  final List<Medication> meds;
  final double tapping;
}

/// Clinica demo: 4 pacienți fictivi, generați la fel la fiecare pornire, plus Ion Popescu cu datele de pe telefon.
/// Nu sunt date reale; dispar odată cu Supabase.
class DemoClinic implements ClinicRepository {
  DemoClinic(this._db, {DateTime Function()? clock, this.threshold = 60}) : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  /// Pragul lui Ion (din setările telefonului).
  final int threshold;

  static final _created = DateTime(2026, 1, 1);

  static final _profiles = <_Profile>[
    _Profile(
      const ClinicPatient(id: 'p-maria', name: 'Maria Ionescu', age: 72, diagnosis: 'tremor esențial'),
      base: 46,
      evening: 8,
      recentRise: 0.2,
      meds: [
        Medication(
          id: 101,
          userId: 'p-maria',
          name: 'Propranolol',
          strength: '40 mg',
          times: const ['08:00', '20:00'],
          stock: 34,
          packSize: 50,
          createdAt: _created,
        ),
      ],
      tapping: 2.4,
    ),
    _Profile(
      const ClinicPatient(id: 'p-gheorghe', name: 'Gheorghe Dumitru', age: 65, diagnosis: 'boala Parkinson'),
      base: 40,
      evening: 10,
      adherence: 0.76,
      meds: [
        Medication(
          id: 102,
          userId: 'p-gheorghe',
          name: 'Madopar',
          strength: '250 mg',
          times: const ['08:00', '14:00', '20:00'],
          stock: 9,
          packSize: 100,
          createdAt: _created,
        ),
        Medication(
          id: 103,
          userId: 'p-gheorghe',
          name: 'Azilect',
          strength: '1 mg',
          times: const ['08:00'],
          stock: 20,
          packSize: 30,
          color: 2,
          createdAt: _created,
        ),
      ],
      tapping: 2.8,
    ),
    _Profile(
      const ClinicPatient(id: 'p-vasile', name: 'Vasile Marin', age: 70, diagnosis: 'boala Parkinson'),
      base: 36,
      evening: 9,
      silentDays: 4,
      meds: [
        Medication(
          id: 104,
          userId: 'p-vasile',
          name: 'Sinemet',
          strength: '25/250 mg',
          times: const ['08:00', '14:00', '20:00'],
          stock: 60,
          packSize: 100,
          color: 1,
          createdAt: _created,
        ),
      ],
      tapping: 3.1,
    ),
    _Profile(
      const ClinicPatient(id: 'p-elena', name: 'Elena Stan', age: 59, diagnosis: 'tremor esențial'),
      base: 24,
      evening: 5,
      adherence: 1,
      meds: [
        Medication(
          id: 105,
          userId: 'p-elena',
          name: 'Primidonă',
          strength: '250 mg',
          times: const ['20:00'],
          stock: 40,
          packSize: 50,
          color: 3,
          createdAt: _created,
        ),
      ],
      tapping: 3.6,
    ),
  ];

  @override
  Future<List<ClinicPatient>> patients() async => [for (final p in _profiles) p.patient, localPatient];

  @override
  Future<PatientRecord> record(String patientId, {required DateTime from, required DateTime to}) async {
    if (patientId == localPatient.id) return localRecord(_db, from: from, to: to, threshold: threshold);
    final p = _profiles.firstWhere((x) => x.patient.id == patientId);
    return _generate(p, from: from, to: to, now: _clock());
  }

  /// Datele zilnice ale pacientului: două sesiuni (dimineața, seara) și, în majoritatea zilelor, un test de tapping.
  PatientRecord _generate(_Profile p, {required DateTime from, required DateTime to, required DateTime now}) {
    final today = DateTime(now.year, now.month, now.day);
    final samples = <SampleRecord>[];
    final sessions = <SessionRecord>[];
    final taps = <double>[];
    final intakes = <Intake>[];
    var sessionId = 1;
    for (var day = DateTime(from.year, from.month, from.day); day.isBefore(to); day = DateTime(day.year, day.month, day.day + 1)) {
      // Același șir de numere pentru aceeași zi și același pacient, la fiecare pornire.
      final r = Random(day.millisecondsSinceEpoch ~/ 86400000 * 31 + p.patient.id.hashCode);
      final daysAgo = today.difference(day).inDays;
      final rise = daysAgo < 7 ? 1 + p.recentRise * (7 - daysAgo) / 7 : 1.0;
      final silent = daysAgo < p.silentDays;
      for (final m in p.meds) {
        for (final t in m.times) {
          final at = atTime(day, t);
          if (at.isAfter(now) || at.isBefore(from)) continue;
          if (r.nextDouble() < p.adherence) {
            intakes.add(
              Intake(
                medId: m.id!,
                scheduledAt: at,
                status: IntakeStatus.taken,
                at: at.add(Duration(minutes: r.nextInt(30))),
              ),
            );
          }
        }
      }
      if (silent || r.nextDouble() < 0.06) continue;
      for (final (hour, extra) in [(9, 0.0), (19, p.evening)]) {
        final start = day.add(Duration(hours: hour, minutes: r.nextInt(50)));
        if (start.isAfter(now) || start.isBefore(from)) continue;
        final level = (p.base + extra) * rise + (r.nextDouble() - 0.5) * 8;
        var alerts = 0;
        var maxI = 0;
        var sum = 0;
        for (var i = 0; i < 24; i++) {
          final idx = (level + (r.nextDouble() - 0.5) * 22 + (daysAgo == 0 && p.recentRise > 0 && i > 14 ? 24 : 0)).round().clamp(0, 100);
          if (idx > p.patient.threshold && (i == 0 || samples.last.index <= p.patient.threshold)) alerts++;
          maxI = max(maxI, idx);
          sum += idx;
          samples.add(
            SampleRecord(
              at: start.add(Duration(seconds: i * 12)),
              frequency: 4.4 + r.nextDouble(),
              rms: idx * 0.3,
              index: idx,
              state: HandState.rest,
              fingers: const [null, null, null, null, null],
            ),
          );
        }
        sessions.add(
          SessionRecord(
            id: sessionId++,
            startedAt: start,
            endedAt: start.add(Duration(minutes: 5 + r.nextInt(6))),
            activity: HandState.rest,
            note: '',
            avgFrequency: 4.8,
            avgIndex: (sum / 24).round(),
            maxIndex: maxI,
            alertCount: alerts,
            simulated: true,
            kind: hour == 9 && r.nextDouble() < 0.7 ? SessionKind.assessment : SessionKind.free,
          ),
        );
      }
      if (r.nextDouble() < 0.7) taps.add(double.parse((p.tapping / rise + (r.nextDouble() - 0.5) * 0.4).toStringAsFixed(2)));
    }
    sessions.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return PatientRecord(patient: p.patient, samples: samples, sessions: sessions, tapping: taps, meds: p.meds, intakes: intakes);
  }
}
