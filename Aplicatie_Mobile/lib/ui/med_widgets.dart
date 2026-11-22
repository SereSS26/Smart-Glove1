import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/theme.dart';
import '../services/feedback.dart';

/// Cerc colorat cu o pastilă: culoarea aleasă pentru medicament.
class PillAvatar extends StatelessWidget {
  const PillAvatar({super.key, required this.color, this.size = 44, this.icon = Symbols.pill_rounded});

  final Color color;
  final double size;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: AppColors.isDark ? 0.28 : 0.16),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: size * 0.55, color: color, fill: 1),
    );
  }
}

/// Bara stocului: cât a rămas din cutie; roșie când ajunge pentru puține zile.
class StockBar extends StatelessWidget {
  const StockBar({super.key, required this.fraction, required this.low, this.height = 10});

  final double fraction;
  final bool low;
  final double height;

  @override
  Widget build(BuildContext context) {
    final color = low ? AppColors.bad : AppColors.ok;
    return Semantics(
      label: 'Stoc ${(fraction * 100).round()} % din cutie',
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: Stack(
          children: [
            Container(height: height, color: AppColors.divider),
            FractionallySizedBox(
              widthFactor: fraction.clamp(0.0, 1.0),
              child: Container(height: height, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// O pastilă mare care se poate bifa (ore, zile, forme). Minimum 48 dp.
class ToggleChip extends StatelessWidget {
  const ToggleChip({super.key, required this.label, required this.selected, required this.onTap, this.icon, this.semanticsLabel});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColors.accentDark : AppColors.text;
    return Semantics(
      label: semanticsLabel,
      selected: selected,
      button: true,
      excludeSemantics: semanticsLabel != null,
      child: Material(
        color: selected ? AppColors.accentSoft : AppColors.surfaceRaised,
        shape: StadiumBorder(side: BorderSide(color: selected ? AppColors.accent : AppColors.border, width: 2)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () {
            Haptics.selection();
            onTap();
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (selected) ...[
                    Icon(Symbols.check_rounded, size: 18, color: fg),
                    const SizedBox(width: 4),
                  ] else if (icon != null) ...[
                    Icon(icon, size: 18, color: fg),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: fg),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Eticheta unui câmp din formular, cu o explicație opțională.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key, this.hint});

  final String text;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          if (hint != null) Text(hint!, style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
