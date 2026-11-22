import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Culoarea fiecărui deget, aceeași pe mână, în listă și pe grafic.
Color fingerColor(int i) => i.isEven ? AppColors.accent : AppColors.accentDark;

/// Mâna desenată: fiecare deget se umple de jos în sus după cât e îndoit.
/// Degetele necalibrate (null) apar cu contur punctat. Ordinea: mare, arătător, mijlociu, inelar, mic.
class LiveHand extends StatelessWidget {
  const LiveHand({super.key, required this.fingers, this.width = 112});

  final List<int?> fingers;
  final double width;

  static const _names = ['degetul mare', 'arătătorul', 'mijlociul', 'inelarul', 'degetul mic'];

  @override
  Widget build(BuildContext context) {
    final parts = [
      for (var i = 0; i < 5; i++) '${_names[i]} ${i < fingers.length && fingers[i] != null ? '${fingers[i]} la sută' : 'necalibrat'}',
    ];
    return Semantics(
      label: 'Mâna: ${parts.join(', ')}',
      excludeSemantics: true,
      child: SizedBox(
        width: width,
        height: width * 160 / 150,
        child: CustomPaint(
          painter: _HandPainter(
            fingers: [for (var i = 0; i < 5; i++) i < fingers.length ? fingers[i] : null],
            colors: [for (var i = 0; i < 5; i++) fingerColor(i)],
            track: AppColors.track,
            palm: AppColors.surfaceRaised,
            border: AppColors.border,
            dashed: AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _HandPainter extends CustomPainter {
  _HandPainter({
    required this.fingers,
    required this.colors,
    required this.track,
    required this.palm,
    required this.border,
    required this.dashed,
  });

  final List<int?> fingers;
  final List<Color> colors;
  final Color track, palm, border, dashed;

  // Dreptunghiurile degetelor pe grila de 150×160 (ca în machete): x, y, lățime, înălțime.
  static const _rects = [
    Rect.fromLTWH(30, 62, 20, 58), // mare (rotit)
    Rect.fromLTWH(46, 20, 20, 72),
    Rect.fromLTWH(70, 8, 20, 84),
    Rect.fromLTWH(94, 16, 20, 76),
    Rect.fromLTWH(117, 34, 18, 58),
  ];

  void _finger(Canvas canvas, int i) {
    final r = _rects[i];
    final radius = Radius.circular(r.width / 2);
    final value = fingers[i];
    if (value == null) {
      final path = Path()..addRRect(RRect.fromRectAndRadius(r.deflate(1), radius));
      final paint = Paint()
        ..color = dashed
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      for (final metric in path.computeMetrics()) {
        for (var d = 0.0; d < metric.length; d += 8) {
          canvas.drawPath(metric.extractPath(d, d + 4), paint);
        }
      }
      return;
    }
    canvas.drawRRect(RRect.fromRectAndRadius(r, radius), Paint()..color = track);
    final h = r.height * value.clamp(0, 100) / 100;
    if (h > 0) {
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(r.left, r.bottom - h, r.width, h), radius), Paint()..color = colors[i]);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 150, size.height / 160);
    // Degetul mare, înclinat spre stânga.
    canvas.save();
    canvas.translate(40, 118);
    canvas.rotate(-30 * math.pi / 180);
    canvas.translate(-40, -118);
    _finger(canvas, 0);
    canvas.restore();
    for (var i = 1; i < 5; i++) {
      _finger(canvas, i);
    }
    // Palma, peste baza degetelor.
    final palmRect = RRect.fromRectAndRadius(const Rect.fromLTWH(38, 82, 100, 72), const Radius.circular(30));
    canvas.drawRRect(palmRect, Paint()..color = palm);
    canvas.drawRRect(
      palmRect,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HandPainter old) =>
      !_sameList(old.fingers, fingers) || old.track != track || old.palm != palm || old.border != border || old.dashed != dashed;

  static bool _sameList(List<int?> a, List<int?> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
