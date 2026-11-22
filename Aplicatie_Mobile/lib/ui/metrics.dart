import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Diferența față de perioada anterioară: săgeată + procent + cuvânt („▼ 12 % · mai bine”).
/// La tremor, mai puțin înseamnă mai bine ([lowerIsBetter]); la tapping, invers.
class DeltaBadge extends StatelessWidget {
  const DeltaBadge({super.key, required this.percent, this.lowerIsBetter = true, this.showWord = true});

  final int percent;
  final bool lowerIsBetter;
  final bool showWord;

  @override
  Widget build(BuildContext context) {
    final better = percent == 0 ? null : (percent < 0) == lowerIsBetter;
    final bg = better == null ? AppColors.track : (better ? AppColors.okBg : AppColors.badBg);
    final fg = better == null ? AppColors.textMuted : (better ? AppColors.okFg : AppColors.badFg);
    final word = better == null ? 'la fel' : (better ? 'mai bine' : 'mai rău');
    final text = percent == 0 ? '0 %' : '${percent.abs()} %';
    return Semantics(
      label: percent == 0 ? 'la fel ca înainte' : '${percent < 0 ? 'scade' : 'crește'} cu ${percent.abs()} la sută, $word',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (percent != 0) Icon(percent < 0 ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded, size: 16, color: fg),
            const SizedBox(width: 2),
            Text(
              showWord && percent != 0 ? '$text · $word' : text,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: fg),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cartonaș cu o cifră mare: eticheta sus, valoarea, apoi o insignă sau o explicație.
class MetricTile extends StatelessWidget {
  const MetricTile({super.key, required this.label, required this.value, this.badge, this.sub, this.valueColor});

  final String label;
  final String value;
  final Widget? badge;
  final String? sub;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  fontFeatures: tabular,
                  color: valueColor ?? AppColors.text,
                ),
              ),
              ?badge,
            ],
          ),
          if (sub != null) ...[
            const SizedBox(height: 4),
            Text(sub!, style: TextStyle(fontSize: 14, color: AppColors.textMuted, height: 1.3)),
          ],
        ],
      ),
    );
  }
}

/// Cartonașe câte două pe rând; fiecare rând e cât cel mai înalt cartonaș, deci textul mărit nu e tăiat.
class MetricGrid extends StatelessWidget {
  const MetricGrid({super.key, required this.children, this.spacing = 10});

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i += 2) ...[
          if (i > 0) SizedBox(height: spacing),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: children[i]),
                SizedBox(width: spacing),
                Expanded(child: i + 1 < children.length ? children[i + 1] : const SizedBox.shrink()),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Stare goală: ilustrație simplă, o propoziție și, dacă are sens, un buton.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.text, this.actionLabel, this.onAction});

  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(color: AppColors.accentSoft, shape: BoxShape.circle),
            child: Icon(icon, size: 42, color: AppColors.accentDark),
          ),
          const SizedBox(height: 14),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, height: 1.4, color: AppColors.textMuted),
          ),
          if (actionLabel != null) ...[const SizedBox(height: 14), OutlinedButton(onPressed: onAction, child: Text(actionLabel!))],
        ],
      ),
    );
  }
}
