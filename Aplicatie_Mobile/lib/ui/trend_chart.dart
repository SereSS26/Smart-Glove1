import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Linia cu arie a indicelui (0–100, cea mai nouă valoare la dreapta), cu banda pragului.
/// Bucățile de peste prag se colorează în roșu, ca să se vadă dintr-o privire.
class TrendChart extends StatelessWidget {
  const TrendChart({
    super.key,
    required this.values,
    this.threshold,
    this.height = 72,
    this.semanticsLabel = 'Intensitatea tremorului în ultimele 30 de secunde',
    this.lastDot = true,
  });

  final List<double> values;
  final int? threshold;
  final double height;
  final String semanticsLabel;
  final bool lastDot;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _TrendPainter(
            values: values,
            threshold: threshold,
            line: AppColors.accent,
            danger: AppColors.bad,
            base: AppColors.border,
            lastDot: lastDot,
          ),
        ),
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.values,
    required this.threshold,
    required this.line,
    required this.danger,
    required this.base,
    required this.lastDot,
  });

  final List<double> values;
  final int? threshold;
  final Color line, danger, base;
  final bool lastDot;

  @override
  void paint(Canvas canvas, Size size) {
    const top = 6.0;
    final bottom = size.height - 4;
    double y(double v) => bottom - (v.clamp(0, 100) / 100) * (bottom - top);

    canvas.drawLine(
      Offset(0, bottom),
      Offset(size.width, bottom),
      Paint()
        ..color = base
        ..strokeWidth = 1,
    );

    double? ty;
    if (threshold != null) {
      ty = y(threshold!.toDouble());
      canvas.drawRect(Rect.fromLTRB(0, 0, size.width, ty), Paint()..color = danger.withValues(alpha: 0.07));
      final dash = Paint()
        ..color = danger.withValues(alpha: 0.8)
        ..strokeWidth = 1.5;
      for (var x = 0.0; x < size.width; x += 10) {
        canvas.drawLine(Offset(x, ty), Offset((x + 5).clamp(0, size.width), ty), dash);
      }
    }
    if (values.length < 2) return;

    final step = size.width / (values.length - 1);
    Offset point(int i) => Offset(i * step, y(values[i]));
    final path = Path()..moveTo(point(0).dx, point(0).dy);
    for (var i = 1; i < values.length; i++) {
      path.lineTo(point(i).dx, point(i).dy);
    }
    final area = Path.from(path)
      ..lineTo(size.width, bottom)
      ..lineTo(0, bottom)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [line.withValues(alpha: 0.22), line.withValues(alpha: 0.02)],
        ).createShader(Rect.fromLTRB(0, top, size.width, bottom)),
    );
    final stroke = Paint()
      ..color = line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, stroke);
    if (ty != null) {
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(0, 0, size.width, ty));
      canvas.drawPath(path, stroke..color = danger);
      canvas.restore();
    }
    if (lastDot) {
      final last = point(values.length - 1) - const Offset(3, 0);
      final over = ty != null && last.dy < ty;
      canvas.drawCircle(last, 5, Paint()..color = over ? danger : line);
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.values != values || old.threshold != threshold || old.line != line || old.danger != danger || old.base != base;
}
