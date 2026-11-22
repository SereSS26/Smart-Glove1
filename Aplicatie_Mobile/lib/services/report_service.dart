import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../core/format.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../data/db/models.dart';
import 'history_stats.dart';

/// Ce intră în raportul unei perioade (pacient sau medic).
class PeriodReport {
  const PeriodReport({
    required this.patient,
    required this.details,
    required this.stats,
    this.sessions = const [],
    this.tappingRate,
    this.adherence,
    this.medications = const [],
    this.includeCharts = true,
    this.includeSessions = true,
  });

  final String patient;
  final String details;
  final PeriodStats stats;
  final List<SessionRecord> sessions;
  final double? tappingRate;
  final int? adherence;

  /// Rânduri de forma „Madopar 250 mg · 08:00, 14:00, 20:00”.
  final List<String> medications;
  final bool includeCharts;
  final bool includeSessions;
}

/// Raportul PDF al unei perioade: cifrele, graficul cu pragul, sesiunile și medicația.
class ReportService {
  static String fileName(PeriodReport r) =>
      'raport_${r.patient.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}_${Fmt.fileStamp(r.stats.range.start)}.pdf';

  static Future<Uint8List> build(PeriodReport r, {required int threshold}) async {
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/AtkinsonHyperlegibleNext-Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/AtkinsonHyperlegibleNext-Bold.ttf'));
    const paper = AppPalette.light;
    final accent = PdfColor.fromInt(paper.accent.toARGB32());
    final deep = PdfColor.fromInt(paper.accentDark.toARGB32());
    final muted = PdfColor.fromInt(paper.textMuted.toARGB32());
    final bad = PdfColor.fromInt(paper.bad.toARGB32());
    final s = r.stats;

    String pct(double? v) => v == null ? '—' : '${v.round()} %';
    final rows = <List<String>>[
      ['Media indicelui', s.mean == null ? '—' : '${s.mean!.round()} (${Severity.fromIndex(s.mean!.round()).label})'],
      ['Față de perioada anterioară', s.deltaPercent == null ? '—' : '${s.deltaPercent! > 0 ? '+' : ''}${s.deltaPercent} %'],
      ['Timp peste prag ($threshold)', pct(s.overThreshold)],
      ['Vârf', s.peak?.toString() ?? '—'],
      ['Sesiuni · zile cu teste', '${s.sessions} · ${s.testDays}'],
      if (r.tappingRate != null) ['Tapping cu mănușa', '${r.tappingRate!.toStringAsFixed(1).replaceAll('.', ',')} atingeri/s'],
      if (r.adherence != null) ['Aderență la medicamente', '${r.adherence} %'],
    ];
    final bars = s.bars.where((b) => b.value != null).toList();

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        footer: (c) => pw.Text(S.pdfFooter, style: pw.TextStyle(fontSize: 9, color: muted)),
        build: (c) => [
          pw.Text(
            'Raport tremor · ${r.patient}',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: deep),
          ),
          pw.SizedBox(height: 2),
          pw.Text('${r.details} · ${s.range.label}', style: pw.TextStyle(fontSize: 12, color: muted)),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            data: rows,
            cellStyle: const pw.TextStyle(fontSize: 11),
            cellAlignments: {1: pw.Alignment.centerRight},
            headerCount: 0,
            border: pw.TableBorder(horizontalInside: pw.BorderSide(color: PdfColor.fromInt(paper.border.toARGB32()))),
          ),
          if (r.includeCharts && bars.length >= 2) ...[
            pw.SizedBox(height: 18),
            pw.Text('Indicele de tremor (0–100), linia roșie = pragul', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.SizedBox(
              height: 160,
              child: pw.Chart(
                grid: pw.CartesianGrid(
                  xAxis: pw.FixedAxis.fromStrings([for (final b in bars) b.label], marginStart: 12, marginEnd: 12),
                  yAxis: pw.FixedAxis([0, 20, 40, 60, 80, 100], divisions: true),
                ),
                datasets: [
                  pw.BarDataSet(
                    color: accent,
                    width: 10,
                    data: [for (var i = 0; i < bars.length; i++) pw.PointChartValue(i.toDouble(), bars[i].value!)],
                  ),
                  pw.LineDataSet(
                    color: bad,
                    drawPoints: false,
                    lineWidth: 1,
                    data: [
                      pw.PointChartValue(0, threshold.toDouble()),
                      pw.PointChartValue((bars.length - 1).toDouble(), threshold.toDouble()),
                    ],
                  ),
                ],
              ),
            ),
          ],
          if (r.medications.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            pw.Text('Medicație', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            for (final m in r.medications) pw.Text('• $m', style: const pw.TextStyle(fontSize: 11)),
          ],
          if (r.includeSessions && r.sessions.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            pw.Text('Sesiuni', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.TableHelper.fromTextArray(
              headers: ['Data', 'Fel', 'Durată', 'Indice mediu', 'Maxim'],
              data: [
                for (final x in r.sessions.take(60))
                  [
                    Fmt.longDate(x.startedAt),
                    switch (x.kind) {
                      SessionKind.free => 'liberă',
                      SessionKind.assessment => 'evaluare',
                      SessionKind.test => 'test',
                    },
                    Fmt.duration(x.duration),
                    '${x.avgIndex}',
                    '${x.maxIndex}',
                  ],
              ],
              headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 10),
            ),
          ],
        ],
      ),
    );
    return doc.save();
  }

  /// Scrie rapoartele în fișiere și le trimite prin meniul de partajare (câte un fișier pe raport).
  static Future<void> share(
    List<PeriodReport> reports, {
    required int threshold,
    String? csv,
    String? csvName,
    List<(String name, String content)> csvFiles = const [],
  }) async {
    final dir = (await getTemporaryDirectory()).path;
    final files = <XFile>[];
    for (final r in reports) {
      final f = File(p.join(dir, fileName(r)));
      await f.writeAsBytes(await build(r, threshold: threshold));
      files.add(XFile(f.path, mimeType: 'application/pdf'));
    }
    if (csv != null) {
      final f = File(p.join(dir, csvName ?? 'date.csv'));
      await f.writeAsString('﻿$csv');
      files.add(XFile(f.path, mimeType: 'text/csv'));
    }
    for (final (name, content) in csvFiles) {
      final f = File(p.join(dir, name));
      await f.writeAsString('\uFEFF$content');
      files.add(XFile(f.path, mimeType: 'text/csv'));
    }
    if (files.isEmpty) return;
    await SharePlus.instance.share(
      ShareParams(files: files, subject: reports.length == 1 ? 'Raport tremor · ${reports.first.patient}' : 'Rapoarte tremor'),
    );
  }
}

/// CSV pe zile pentru medic: media, maximul, timpul peste prag, sesiunile și dozele luate.
/// Separator „;” și virgulă zecimală, ca să se deschidă corect în Excel în română.
String dailyCsv({
  required List<SampleRecord> samples,
  required List<SessionRecord> sessions,
  required Map<DateTime, int> dosesByDay,
  required DateTime from,
  required DateTime to,
  required int threshold,
}) {
  final b = StringBuffer('Data;Media indicelui;Maxim;Peste prag ($threshold) %;Sesiuni;Doze luate\n');
  final byDay = <DateTime, List<int>>{};
  for (final s in samples) {
    byDay.putIfAbsent(DateTime(s.at.year, s.at.month, s.at.day), () => []).add(s.index);
  }
  for (var d = DateTime(from.year, from.month, from.day); d.isBefore(to); d = DateTime(d.year, d.month, d.day + 1)) {
    final v = byDay[d] ?? const <int>[];
    final n = sessions.where((s) => s.startedAt.year == d.year && s.startedAt.month == d.month && s.startedAt.day == d.day).length;
    final mean = v.isEmpty ? '' : (v.reduce((a, b) => a + b) / v.length).toStringAsFixed(1).replaceAll('.', ',');
    final mx = v.isEmpty ? '' : '${v.reduce((a, b) => a > b ? a : b)}';
    final over = v.isEmpty ? '' : (100 * v.where((x) => x > threshold).length / v.length).toStringAsFixed(1).replaceAll('.', ',');
    b.writeln(
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')};$mean;$mx;$over;$n;${dosesByDay[d] ?? 0}',
    );
  }
  return b.toString();
}
