import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Sigla: o palmă cu o linie de puls, desenată pe o grilă de 48×48 (ca în machete).
class HandPulseLogo extends StatelessWidget {
  const HandPulseLogo({super.key, this.size = 48, this.color = Colors.white, this.strokeWidth = 2.6});

  final double size;
  final Color color;

  /// Grosimea liniei, în unitățile grilei de 48.
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Sigla Mănușa',
      image: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: HandPulsePainter(color: color, strokeWidth: strokeWidth),
        ),
      ),
    );
  }
}

class HandPulsePainter extends CustomPainter {
  HandPulsePainter({required this.color, this.strokeWidth = 2.6});

  final Color color;
  final double strokeWidth;

  static Path hand() {
    const r = Radius.circular(2.5);
    return Path()
      // Arătătorul
      ..moveTo(15, 25)
      ..lineTo(15, 12.5)
      ..arcToPoint(const Offset(20, 12.5), radius: r)
      ..lineTo(20, 22)
      // Mijlociul
      ..moveTo(20, 21)
      ..lineTo(20, 9.5)
      ..arcToPoint(const Offset(25, 9.5), radius: r)
      ..lineTo(25, 21)
      // Inelarul
      ..moveTo(25, 21)
      ..lineTo(25, 11)
      ..arcToPoint(const Offset(30, 11), radius: r)
      ..lineTo(30, 21)
      // Degetul mic, marginea palmei și degetul mare
      ..moveTo(30, 22)
      ..lineTo(30, 15.5)
      ..arcToPoint(const Offset(35, 15.5), radius: r)
      ..lineTo(35, 29)
      ..cubicTo(35, 36, 30, 41, 23.5, 41)
      ..lineTo(22.5, 41)
      ..cubicTo(17, 41, 13.5, 38, 11.5, 34)
      ..lineTo(8, 27.5)
      ..arcToPoint(const Offset(12.3, 24.9), radius: r)
      ..lineTo(15, 29);
  }

  static Path pulse() => Path()
    ..moveTo(16.5, 33)
    ..lineTo(19.5, 33)
    ..lineTo(21.5, 29.5)
    ..lineTo(24, 35.5)
    ..lineTo(26, 31)
    ..lineTo(30.5, 31);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 48, size.height / 48);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(hand(), paint);
    canvas.drawPath(pulse(), paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(HandPulsePainter old) => old.color != color || old.strokeWidth != strokeWidth;
}

/// Iconița aplicației: pătrat rotunjit în degradeu roz, cu sigla albă.
class AppMark extends StatelessWidget {
  const AppMark({super.key, this.size = 96, this.shadow = true});

  final double size;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.29),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE8508A), Color(0xFFB8285F)],
        ),
        boxShadow: shadow ? AppShadows.button : null,
      ),
      alignment: Alignment.center,
      child: HandPulseLogo(size: size * 0.64),
    );
  }
}
