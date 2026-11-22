import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Grup de rânduri într-un cartonaș, cu linii subțiri între ele (Setări).
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppSizes.radius), boxShadow: AppShadows.card),
      child: Material(
        clipBehavior: Clip.antiAlias,
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radius),
          side: BorderSide(color: AppColors.cardBorder),
        ),
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) Divider(height: 1, thickness: 1, indent: 16, endIndent: 16, color: AppColors.divider),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// Rând care deschide alt ecran: titlu, explicație și săgeată.
class NavRow extends StatelessWidget {
  const NavRow({super.key, required this.title, this.subtitle, required this.onTap, this.icon, this.danger = false});

  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final IconData? icon;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.recording : AppColors.text;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
          child: Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, size: 22, color: AppColors.accentDark),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color),
                    ),
                    if (subtitle != null) Text(subtitle!, style: TextStyle(fontSize: 15, color: AppColors.textMuted)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rând cu comutator pornit/oprit.
class SwitchRow extends StatelessWidget {
  const SwitchRow({super.key, required this.title, this.subtitle, required this.value, required this.onChanged});

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: InkWell(
        onTap: () => onChanged(!value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 10, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      if (subtitle != null) Text(subtitle!, style: TextStyle(fontSize: 15, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Switch(value: value, onChanged: onChanged),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
