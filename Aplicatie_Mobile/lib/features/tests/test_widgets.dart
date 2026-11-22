import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/tests.dart';
import '../../core/theme.dart';

/// Iconița fiecărui test.
IconData testIcon(TestKind t) => switch (t) {
  TestKind.rest => Symbols.back_hand_rounded,
  TestKind.postural => Symbols.front_hand_rounded,
  TestKind.kinetic => Symbols.touch_app_rounded,
  TestKind.tappingGlove => Symbols.pinch_rounded,
  TestKind.tappingScreen => Symbols.smartphone_rounded,
};

/// Eticheta scurtă din evaluare („1 · Repaus”).
String testShortName(TestKind t) => switch (t) {
  TestKind.rest => 'Repaus',
  TestKind.postural => 'Postural',
  TestKind.kinetic => 'În mișcare',
  TestKind.tappingGlove => 'Tapping',
  TestKind.tappingScreen => 'Tapping pe ecran',
};

/// Rezultatul pe scurt: „42” sau „3,2 atingeri/s”.
String formatTestValue(TestKind t, double v) => t.isTremor ? '${v.round()}' : '${v.toStringAsFixed(1).replaceAll('.', ',')} atingeri/s';

/// Inelul de timp al testului: se golește pe măsură ce trec secundele.
class CountdownRing extends StatelessWidget {
  const CountdownRing({super.key, required this.fraction, required this.label, required this.caption, this.size = 200});

  final double fraction;
  final String label;
  final String caption;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label $caption',
      liveRegion: true,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _RingPainter(fraction: fraction.clamp(0, 1), color: AppColors.accent, track: AppColors.track),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(fontSize: size * 0.32, fontWeight: FontWeight.w800, height: 1, fontFeatures: tabular),
                  ),
                  Text(caption, style: TextStyle(fontSize: 16, color: AppColors.textMuted)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.fraction, required this.color, required this.track});
  final double fraction;
  final Color color, track;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.07;
    final c = size.center(Offset.zero);
    final r = size.width / 2 - stroke / 2 - 2;
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    if (fraction > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        -math.pi / 2,
        2 * math.pi * fraction,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.fraction != fraction || old.color != color;
}

/// Bara de pași din evaluare: plin = gata, pe jumătate = pasul curent.
class StepBar extends StatelessWidget {
  const StepBar({super.key, required this.count, required this.current, required this.progress});

  final int count;
  final int current;

  /// Cât din pasul curent a trecut (0–1).
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Pasul ${current + 1} din $count',
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 0; i < count; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: i < current ? 1 : (i == current ? progress : 0),
                  minHeight: 8,
                  color: AppColors.accent,
                  backgroundColor: AppColors.track,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Testul de tapping pe ecran: două cercuri mari; cel de atins acum e plin.
class TapTargets extends StatelessWidget {
  const TapTargets({super.key, required this.next, required this.onHit, required this.onMiss, required this.enabled});

  /// 0 = cercul din stânga, 1 = cel din dreapta.
  final int next;
  final ValueChanged<int> onHit;
  final VoidCallback onMiss;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    Widget target(int i) {
      final active = enabled && i == next;
      return Semantics(
        button: true,
        label: i == 0 ? 'Cercul din stânga' : 'Cercul din dreapta',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => i == next ? onHit(i) : onMiss() : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 132,
            height: 132,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: active ? AppColors.gradient : null,
              color: active ? null : AppColors.accentSoft,
              border: Border.all(color: AppColors.accent, width: 3),
            ),
            child: Icon(Symbols.touch_app_rounded, size: 44, color: active ? Colors.white : AppColors.accentDark),
          ),
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => onMiss() : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [target(0), target(1)]),
      ),
    );
  }
}
