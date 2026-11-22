import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'live_hand.dart';

/// Degetele calibrate în ultimele 30 s: câte o linie pe deget, în aceeași culoare ca pe mână.
class FingerChart extends StatelessWidget {
  const FingerChart({super.key, required this.history, this.height = 40});

  /// Câte o listă de 5 valori pe pachet (null = necalibrat).
  final List<List<int?>> history;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Îndoirea degetelor în ultimele 30 de secunde',
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _FingerPainter(history: history, colors: [for (var i = 0; i < 5; i++) fingerColor(i)], base: AppColors.border),
        ),
      ),
    );
  }
}

class _FingerPainter extends CustomPainter {
  _FingerPainter({required this.history, required this.colors, required this.base});

  final List<List<int?>> history;
  final List<Color> colors;
  final Color base;

  @override
  void paint(Canvas canvas, Size size) {
    final bottom = size.height - 2;
    canvas.drawLine(
      Offset(0, bottom),
      Offset(size.width, bottom),
      Paint()
        ..color = base
        ..strokeWidth = 1,
    );
    if (history.length < 2) return;
    final step = size.width / (history.length - 1);
    for (var f = 0; f < 5; f++) {
      Path? path;
      for (var i = 0; i < history.length; i++) {
        final row = history[i];
        final v = f < row.length ? row[f] : null;
        if (v == null) continue;
        final p = Offset(i * step, bottom - (v.clamp(0, 100) / 100) * (bottom - 3));
        if (path == null) {
          path = Path()..moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      if (path != null) {
        canvas.drawPath(
          path,
          Paint()
            ..color = colors[f]
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4
            ..strokeJoin = StrokeJoin.round
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_FingerPainter old) => old.history != history || old.base != base;
}
