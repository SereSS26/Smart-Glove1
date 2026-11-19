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

/// Raportul PDF și datele CSV ale unei sesiuni, trimise prin meniul de partajare al telefonului.
class ExportService {
  /// Textul CSV: un rând pe secundă. Separator „;” și virgulă zecimală, ca să se deschidă corect în Excel în română.
  static String buildCsv(SessionRecord s, List<SampleRecord> samples) {
    String num(double v) => v.toStringAsFixed(2).replaceAll('.', ',');
    final rows = <String>[
      'timp;secunda;frecventa_hz;rms_dps;indice;activitate;${S.fingerNames.map((n) => 'deget_${n.toLowerCase()}').join(';')}',
      for (final x in samples)
        [
          x.at.toIso8601String(),
          x.at.difference(s.startedAt).inSeconds,
          num(x.frequency),
          num(x.rms),
          x.index,
          x.state.label,
          ...x.fingers.map((f) => f?.toString() ?? ''),
        ].join(';'),
    ];
    return rows.join('\n');
  }

  static Future<void> shareCsv(SessionRecord s, List<SampleRecord> samples) async {
    final file = File(p.join((await getTemporaryDirectory()).path, 'sesiune_${Fmt.fileStamp(s.startedAt)}.csv'));
    // BOM la început: Excel recunoaște diacriticele.
    await file.writeAsString('﻿${buildCsv(s, samples)}');
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/csv')],
        subject: 'Date sesiune ${Fmt.longDate(s.startedAt)}',
      ),
    );
  }

  static Future<void> sharePdf(SessionRecord s, List<SampleRecord> samples, List<EventRecord> events) async {
    final bytes = await buildPdf(s, samples, events);
    final file = File(p.join((await getTemporaryDirectory()).path, 'raport_tremor_${Fmt.fileStamp(s.startedAt)}.pdf'));
    await file.writeAsBytes(bytes);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'Raport tremor ${Fmt.longDate(s.startedAt)}',
      ),
    );
  }

  static Future<Uint8List> buildPdf(SessionRecord s, List<SampleRecord> samples, List<EventRecord> events) async {
    // Fontul aplicației, ca diacriticele să apară corect în PDF.
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/AtkinsonHyperlegible-Regular.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/AtkinsonHyperlegible-Bold.ttf'));
    final accent = PdfColor.fromInt(AppColors.accent.toARGB32());
    final muted = PdfColor.fromInt(AppColors.textMuted.toARGB32());
    final alertColor = PdfColor.fromInt(AppColors.recording.toARGB32());

    final doc = pw.Document(title: 'Raport tremor', author: S.appTitle);
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        theme: pw.ThemeData.withFont(base: regular, bold: bold),
        footer: (c) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(S.pdfFooter, style: pw.TextStyle(fontSize: 9, color: muted)),
            pw.Text('${c.pageNumber}/${c.pagesCount}', style: pw.TextStyle(fontSize: 9, color: muted)),
          ],
        ),
        build: (c) => [
          pw.Text('Raport de tremor', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(
            '${Fmt.longDate(s.startedAt)} · ${Fmt.duration(s.duration)} · ${s.activity.label}${s.simulated ? ' · DATE SIMULATE' : ''}',
            style: pw.TextStyle(fontSize: 12, color: muted),
          ),
          pw.SizedBox(height: 18),
          pw.TableHelper.fromTextArray(
            border: null,
            cellAlignment: pw.Alignment.centerLeft,
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: muted, fontSize: 11),
            cellStyle: const pw.TextStyle(fontSize: 13),
            headers: [S.durationLabel, S.avgFrequency, S.avgIndex, S.maxIndex, 'Alerte'],
            data: [
              [
                Fmt.duration(s.duration),
                s.avgFrequency == null ? '—' : '${Fmt.hz(s.avgFrequency!)} Hz',
                '${s.avgIndex} (${Severity.fromIndex(s.avgIndex).label})',
                '${s.maxIndex} (${Severity.fromIndex(s.maxIndex).label})',
                '${s.alertCount}',
              ],
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Text('${S.indexOverTime} (0–100)', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          _chart(samples, s, accent, alertColor, muted),
          pw.SizedBox(height: 18),
          if (s.note.isNotEmpty) ...[
            pw.Text(S.note, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text(s.note, style: const pw.TextStyle(fontSize: 12)),
            pw.SizedBox(height: 18),
          ],
          if (events.isNotEmpty) ...[
            pw.Text('Evenimente', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            for (final e in events) pw.Text('${Fmt.time(e.at)}  ${_eventLabel(e)}', style: const pw.TextStyle(fontSize: 12)),
          ],
        ],
      ),
    );
    return doc.save();
  }

  static String _eventLabel(EventRecord e) => switch (e.kind) {
    EventKind.alert => 'Alertă: ${e.text}',
    EventKind.mark => 'Moment marcat',
    EventKind.note => 'Notă: ${e.text}',
  };

  static pw.Widget _chart(List<SampleRecord> samples, SessionRecord s, PdfColor line, PdfColor alert, PdfColor muted) {
    if (samples.length < 2) return pw.Text('Prea puține date pentru grafic.', style: pw.TextStyle(color: muted));
    final total = samples.last.at.difference(samples.first.at).inSeconds.clamp(1, 1 << 30).toDouble();
    return pw.SizedBox(
      height: 150,
      child: pw.Chart(
        grid: pw.CartesianGrid(
          xAxis: pw.FixedAxis.fromStrings(
            ['0', Fmt.duration(Duration(seconds: (total / 2).round())), Fmt.duration(Duration(seconds: total.round()))],
            marginStart: 0,
            marginEnd: 0,
          ),
          yAxis: pw.FixedAxis([0, 20, 40, 60, 80, 100], divisions: true),
        ),
        datasets: [
          pw.LineDataSet(
            drawPoints: false,
            isCurved: false,
            color: line,
            lineWidth: 1.5,
            data: [
              for (final x in samples) pw.PointChartValue(2 * x.at.difference(samples.first.at).inSeconds / total, x.index.toDouble()),
            ],
          ),
        ],
      ),
    );
  }
}
