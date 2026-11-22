import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Inelul tremorului: indicele 0–100 ca arc, în culoarea severității, cu un semn la prag.
/// [index] null = fără date: inelul rămâne gol și în mijloc apare o liniuță.
class TremorRing extends StatelessWidget {
  const TremorRing({super.key, required this.index, required this.threshold, this.size = 96, this.caption = 'din 100'});

  final int? index;
  final int threshold;
  final double size;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final v = index;
    final color = v == null ? AppColors.mutedDot : Severity.fromIndex(v).dot;
    return Semantics(
      label: v == null ? 'Indice de tremor: fără date' : 'Indice de tremor $v din 100; pragul tău este $threshold',
      excludeSemantics: true,
      // Inelul se umple lin și cifra se rostogolește spre valoarea nouă; fără animație dacă telefonul cere „Reducere animații”.
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: (v ?? 0).toDouble()),
        duration: MediaQuery.of(context).disableAnimations ? Duration.zero : const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        builder: (context, shown, _) => _ring(v == null ? null : shown, color),
      ),
    );
  }

  Widget _ring(double? shown, Color color) {
    final v = shown?.round();
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _RingPainter(value: shown, threshold: threshold, color: color, track: AppColors.track, tick: AppColors.text),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  v == null ? '–' : '$v',
                  style: TextStyle(
                    fontSize: size * 0.33,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    fontFeatures: tabular,
                    color: v == null ? AppColors.textMuted : AppColors.text,
                  ),
                ),
                if (caption != null)
                  Text(
                    caption!,
                    style: TextStyle(fontSize: size * 0.13, color: AppColors.textMuted),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.value, required this.threshold, required this.color, required this.track, required this.tick});

  final double? value;
  final int threshold;
  final Color color, track, tick;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.1;
    final center = size.center(Offset.zero);
    final r = size.width / 2 - stroke / 2 - 2;
    final rect = Rect.fromCircle(center: center, radius: r);
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    if (value != null && value! > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * value!.clamp(0, 100) / 100,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );
    }
    // Semnul pragului, de-a curmezișul inelului.
    final a = -math.pi / 2 + 2 * math.pi * threshold.clamp(0, 100) / 100;
    final dir = Offset(math.cos(a), math.sin(a));
    canvas.drawLine(
      center + dir * (r - stroke * 0.75),
      center + dir * (r + stroke * 0.75),
      Paint()
        ..color = tick
        ..strokeWidth = math.max(2, size.width * 0.03)
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.threshold != threshold || old.color != color || old.track != track || old.tick != tick;
}
