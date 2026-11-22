import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/feedback.dart';

/// O variantă dintr-o alegere: valoarea, eticheta și, opțional, o iconiță.
class Choice<T> {
  const Choice(this.value, this.label, {this.icon});
  final T value;
  final String label;
  final IconData? icon;
}

/// Plăci mari, una lângă alta, cu iconiță și etichetă (ex. USB · Wi-Fi · Demo).
/// Cea aleasă are contur roz și fundal roz pal.
class ChoiceTiles<T> extends StatelessWidget {
  const ChoiceTiles({super.key, required this.options, required this.selected, required this.onChanged, this.height = 56});

  final List<Choice<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < options.length; i++) ...[if (i > 0) const SizedBox(width: 8), Expanded(child: _tile(options[i]))],
      ],
    );
  }

  Widget _tile(Choice<T> o) {
    final on = o.value == selected;
    final fg = on ? AppColors.accentDark : AppColors.textMuted;
    return Semantics(
      selected: on,
      button: true,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: on ? AppColors.accentSoft : AppColors.surfaceRaised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: on ? AppColors.accent : AppColors.border, width: 2),
        ),
        child: InkWell(
          customBorder: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          onTap: () {
            Haptics.selection();
            onChanged(o.value);
          },
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: height),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (o.icon != null) ...[Icon(o.icon, size: 22, color: fg), const SizedBox(width: 8)],
                    Text(
                      o.label,
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: fg),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Comutator segmentat: o „pastilă” albă alunecă peste un fond roz pal (ex. Zi · Săptămână · Lună).
class AppSegmented<T> extends StatelessWidget {
  const AppSegmented({super.key, required this.options, required this.selected, required this.onChanged, this.height = 52});

  final List<Choice<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.track, borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++) ...[if (i > 0) const SizedBox(width: 4), Expanded(child: _segment(options[i]))],
        ],
      ),
    );
  }

  Widget _segment(Choice<T> o) {
    final on = o.value == selected;
    return Semantics(
      selected: on,
      button: true,
      inMutuallyExclusiveGroup: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: on ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          boxShadow: on ? AppShadows.segment : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              Haptics.selection();
              onChanged(o.value);
            },
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: height - 8),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      o.label,
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: on ? AppColors.accentDark : AppColors.textMuted),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Valoare schimbată cu `−` și `+`, fără tastatură și fără cursor (mai ușor cu o mână care tremură).
class StepperField extends StatelessWidget {
  const StepperField({
    super.key,
    required this.value,
    required this.onMinus,
    required this.onPlus,
    required this.minusLabel,
    required this.plusLabel,
    this.valueWidth = 56,
  });

  final String value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  final String minusLabel;
  final String plusLabel;
  final double valueWidth;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepButton(icon: Icons.remove_rounded, label: minusLabel, onPressed: onMinus),
        SizedBox(
          width: valueWidth,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, fontFeatures: tabular),
            ),
          ),
        ),
        _StepButton(icon: Icons.add_rounded, label: plusLabel, onPressed: onPlus),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 52,
      child: OutlinedButton(
        onPressed: onPressed == null
            ? null
            : () {
                Haptics.selection();
                onPressed!();
              },
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.square(52),
          padding: EdgeInsets.zero,
          side: BorderSide(color: AppColors.border, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          foregroundColor: AppColors.accentDark,
        ),
        child: Icon(icon, size: 26, semanticLabel: label),
      ),
    );
  }
}
