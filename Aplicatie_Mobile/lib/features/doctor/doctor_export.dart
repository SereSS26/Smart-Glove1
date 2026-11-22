import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/clinic_repository.dart';
import '../../data/medications.dart';
import '../../services/report_service.dart';
import '../../state/clinic_providers.dart';

/// Ce intră în export.
class ExportOptions {
  const ExportOptions({required this.days, this.pdf = true, this.charts = true, this.sessions = true, this.meds = true});
  final int days;
  final bool pdf;
  final bool charts;
  final bool sessions;
  final bool meds;
}

String _slug(String name) => name
    .toLowerCase()
    .replaceAll(RegExp('[ăâ]'), 'a')
    .replaceAll('î', 'i')
    .replaceAll(RegExp('[șş]'), 's')
    .replaceAll(RegExp('[țţ]'), 't')
    .replaceAll(RegExp(r'[^a-z0-9]+'), '_');

/// Un fișier pe pacient (PDF cu grafice sau CSV pe zile), trimise împreună prin meniul de partajare.
Future<int> exportPatients(WidgetRef ref, List<ClinicPatient> patients, ExportOptions o) async {
  final clinic = ref.read(clinicProvider);
  final reports = <PeriodReport>[];
  final csvs = <(String, String)>[];
  for (final p in patients) {
    final d = await loadPatientDetail(clinic, p.id, o.days);
    final start = d.stats.range.start;
    final end = d.stats.range.end;
    final sessions = d.record.sessions.where((s) => !s.startedAt.isBefore(start)).toList();
    if (o.pdf) {
      reports.add(
        PeriodReport(
          patient: p.name,
          details: p.details,
          stats: d.stats,
          sessions: o.sessions ? sessions : const [],
          tappingRate: d.record.tapping.isEmpty ? null : d.record.tapping.last,
          adherence: d.adherence,
          medications: o.meds ? [for (final m in d.record.meds) '${m.title} · ${m.doseShort} · ${m.times.join(', ')}'] : const [],
          includeCharts: o.charts,
          includeSessions: o.sessions,
        ),
      );
    } else {
      final doses = <DateTime, int>{};
      for (final i in d.record.intakes) {
        if (i.status == IntakeStatus.taken) doses.update(dayOf(i.scheduledAt), (v) => v + 1, ifAbsent: () => 1);
      }
      csvs.add((
        'date_${_slug(p.name)}_${o.days}_zile.csv',
        dailyCsv(
          samples: d.record.between(start, end),
          sessions: sessions,
          dosesByDay: doses,
          from: start,
          to: end,
          threshold: p.threshold,
        ),
      ));
    }
  }
  await ReportService.share(reports, threshold: patients.isEmpty ? 60 : patients.first.threshold, csvFiles: csvs);
  return reports.length + csvs.length;
}
