import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// O bară din graficul Istoric; [value] null = nicio sesiune în acea zi/oră.
class BarDatum {
  const BarDatum(this.label, this.value, {this.highlight = false, this.dose = false});
  final String label;
  final double? value;
  final bool highlight;

  /// O doză luată în acel interval: o mică pastilă sub bară.
  final bool dose;
}

/// Grafic cu bare (0–100) și linia punctată a pragului de alertă.
class IndexBarChart extends StatelessWidget {
  const IndexBarChart({super.key, required this.bars, required this.threshold, required this.semanticsLabel, this.height = 184});

  final List<BarDatum> bars;
  final int threshold;
  final String semanticsLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _BarPainter(bars, threshold)),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter(this.bars, this.threshold);

  final List<BarDatum> bars;
  final int threshold;

  static const _left = 34.0;
  static const _top = 26.0;
  static const _bottomPad = 34.0;

  void _text(Canvas c, String s, Offset at, {double size = 14, Color? color, bool bold = false, TextAlign align = TextAlign.center}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontFamily: 'Atkinson',
          fontSize: size,
          color: color ?? AppColors.textMuted,
          fontWeight: bold ? FontWeight.w800 : FontWeight.w400,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout();
    final dx = switch (align) {
      TextAlign.center => at.dx - tp.width / 2,
      TextAlign.right || TextAlign.end => at.dx - tp.width,
      _ => at.dx,
    };
    tp.paint(c, Offset(dx, at.dy - tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final bottom = size.height - _bottomPad;
    final plotW = size.width - _left;
    double y(double v) => bottom - (v.clamp(0, 100) / 100) * (bottom - _top);

    final grid = Paint()
      ..color = AppColors.track
      ..strokeWidth = 1;
    for (final v in [20, 40, 80]) {
      canvas.drawLine(Offset(_left, y(v.toDouble())), Offset(size.width, y(v.toDouble())), grid);
      _text(canvas, '$v', Offset(_left - 8, y(v.toDouble())), align: TextAlign.right);
    }
    canvas.drawLine(Offset(_left, bottom), Offset(size.width, bottom), grid..color = AppColors.borderStrong);

    // Linia punctată a pragului.
    final ty = y(threshold.toDouble());
    final dash = Paint()
      ..color = AppColors.recording
      ..strokeWidth = 1.5;
    for (var x = _left; x < size.width; x += 10) {
      canvas.drawLine(Offset(x, ty), Offset((x + 5).clamp(0, size.width), ty), dash);
    }
    _text(canvas, 'prag $threshold', Offset(size.width, ty - 12), size: 13, color: AppColors.recording, bold: true, align: TextAlign.right);

    if (bars.isEmpty) return;
    final slot = plotW / bars.length;
    final barW = (slot * 0.6).clamp(6.0, 28.0);
    const labelEvery = 1; // etichetele vin deja rărite (ore din 3 în 3, zile din 5 în 5)
    for (var i = 0; i < bars.length; i++) {
      final b = bars[i];
      final cx = _left + slot * i + slot / 2;
      if (b.value == null) {
        canvas.drawLine(
          Offset(cx - barW / 3, bottom - 4),
          Offset(cx + barW / 3, bottom - 4),
          Paint()
            ..color = AppColors.borderStrong
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round,
        );
      } else {
        final rect = RRect.fromRectAndRadius(Rect.fromLTRB(cx - barW / 2, y(b.value!), cx + barW / 2, bottom), const Radius.circular(6));
        final over = b.value! > threshold;
        final color = over ? AppColors.bad : AppColors.accent;
        canvas.drawRRect(rect, Paint()..color = b.highlight ? color : color.withValues(alpha: 0.75));
        if (bars.length <= 12) {
          _text(
            canvas,
            b.value!.round().toString(),
            Offset(cx, y(b.value!) - 11),
            size: 14,
            color: over ? AppColors.recording : AppColors.text,
            bold: true,
          );
        }
      }
      if (b.dose) {
        final pill = RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, bottom + 4), width: 12, height: 6),
          const Radius.circular(3),
        );
        canvas.drawRRect(pill, Paint()..color = AppColors.accentDark);
      }
      if (i % labelEvery == 0) {
        _text(
          canvas,
          b.label,
          Offset(cx, bottom + 18),
          size: 15,
          color: b.highlight ? AppColors.text : AppColors.textMuted,
          bold: b.highlight,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) => old.bars != bars || old.threshold != threshold;
}

/// Graficul unei sesiuni: indicele în timp, pragul și punctele de alertă.
class SessionChart extends StatelessWidget {
  const SessionChart({super.key, required this.values, required this.alertPositions, required this.threshold});

  /// Indicele pe secunde.
  final List<double> values;

  /// Poziția alertelor, ca fracție 0–1 din durată.
  final List<double> alertPositions;
  final int threshold;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Indicele de tremor pe durata sesiunii, cu ${alertPositions.length} alerte',
      excludeSemantics: true,
      child: SizedBox(
        height: 130,
        width: double.infinity,
        child: CustomPaint(painter: _SessionPainter(values, alertPositions, threshold)),
      ),
    );
  }
}

class _SessionPainter extends CustomPainter {
  _SessionPainter(this.values, this.alerts, this.threshold);

  final List<double> values;
  final List<double> alerts;
  final int threshold;

  @override
  void paint(Canvas canvas, Size size) {
    const top = 8.0;
    final bottom = size.height - 8;
    double y(double v) => bottom - (v.clamp(0, 100) / 100) * (bottom - top);
    canvas.drawLine(
      Offset(0, bottom),
      Offset(size.width, bottom),
      Paint()
        ..color = AppColors.borderStrong
        ..strokeWidth = 1.5,
    );
    if (values.length >= 2) {
      // Cel mult ~200 de puncte, ca graficul să rămână lizibil și pentru sesiuni lungi.
      final step = (values.length / 200).ceil();
      final pts = <Offset>[for (var i = 0; i < values.length; i += step) Offset(size.width * i / (values.length - 1), y(values[i]))];
      final line = Path()..addPolygon(pts, false);
      final area = Path.from(line)
        ..lineTo(pts.last.dx, bottom)
        ..lineTo(0, bottom)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.accent.withValues(alpha: 0.22), AppColors.accent.withValues(alpha: 0.02)],
          ).createShader(Rect.fromLTRB(0, top, size.width, bottom)),
      );
      canvas.drawPath(
        line,
        Paint()
          ..color = AppColors.accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeJoin = StrokeJoin.round,
      );
    }
    final ty = y(threshold.toDouble());
    final dash = Paint()
      ..color = AppColors.recording
      ..strokeWidth = 1.5;
    for (var x = 0.0; x < size.width; x += 10) {
      canvas.drawLine(Offset(x, ty), Offset((x + 5).clamp(0, size.width), ty), dash);
    }
    for (final a in alerts) {
      final x = a.clamp(0.0, 1.0) * size.width;
      final i = (a.clamp(0.0, 1.0) * (values.length - 1)).round().clamp(0, values.isEmpty ? 0 : values.length - 1);
      final cy = values.isEmpty ? ty : y(values[i]);
      canvas.drawCircle(Offset(x, cy), 7, Paint()..color = AppColors.surface);
      canvas.drawCircle(Offset(x, cy), 5.5, Paint()..color = AppColors.recording);
    }
  }

  @override
  bool shouldRepaint(_SessionPainter old) => old.values != values || old.alerts != alerts || old.threshold != threshold;
}
