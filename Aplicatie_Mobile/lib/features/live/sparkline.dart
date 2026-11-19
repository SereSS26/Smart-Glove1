import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Graficul rulant cu intensitatea tremorului (valori 0–100, cea mai nouă la dreapta).
class Sparkline extends StatelessWidget {
  const Sparkline({super.key, required this.values, this.height = 84});

  final List<double> values;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Intensitatea tremorului în ultimele 30 de secunde',
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _SparklinePainter(values)),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter(this.values);

  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    const top = 6.0;
    final bottom = size.height - 6;
    final grid = Paint()
      ..color = AppColors.border
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, bottom), Offset(size.width, bottom), grid);
    canvas.drawLine(Offset(0, (top + bottom) / 2), Offset(size.width, (top + bottom) / 2), grid..color = AppColors.track);
    if (values.length < 2) return;

    final step = size.width / (values.length - 1);
    Offset point(int i) => Offset(i * step, bottom - (values[i].clamp(0, 100) / 100) * (bottom - top));

    final line = Path()..moveTo(point(0).dx, point(0).dy);
    for (var i = 1; i < values.length; i++) {
      line.lineTo(point(i).dx, point(i).dy);
    }
    final area = Path.from(line)
      ..lineTo(size.width, bottom)
      ..lineTo(0, bottom)
      ..close();

    canvas.drawPath(area, Paint()..color = AppColors.accentSoft);
    canvas.drawPath(
      line,
      Paint()
        ..color = AppColors.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(point(values.length - 1) - const Offset(4, 0), 5, Paint()..color = AppColors.accent);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => old.values != values;
}
