import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../services/feedback.dart';

/// Butonul principal: degradeu roz, înalt de 64, cu un puls scurt de vibrație la apăsare
/// (confirmă apăsarea pentru o mână care tremură). [danger] îl face roșu, pentru „Oprește”.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = AppSizes.buttonHeight,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final radius = BorderRadius.circular(AppSizes.buttonRadius);
    final gradient = danger
        ? LinearGradient(colors: [AppColors.recording, Color.lerp(AppColors.recording, Colors.black, 0.18)!])
        : AppColors.gradient;
    final fg = enabled ? (danger && AppColors.isDark ? const Color(0xFF2A0F1B) : Colors.white) : AppColors.textMuted;

    return Semantics(
      button: true,
      enabled: enabled,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: height),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: radius,
            gradient: enabled ? gradient : null,
            color: enabled ? null : AppColors.track,
            boxShadow: enabled && !danger ? AppShadows.button : null,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: radius,
              onTap: enabled
                  ? () {
                      Haptics.light();
                      onPressed!();
                    }
                  : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: enabled ? Colors.white.withValues(alpha: 0.22) : AppColors.border,
                        ),
                        child: Icon(icon, size: 22, color: fg),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: fg),
                      ),
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
