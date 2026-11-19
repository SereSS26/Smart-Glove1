import 'package:flutter/material.dart';

import 'theme.dart';

/// Ecran care umple înălțimea disponibilă, dar devine derulabil când e mai mic decât [minHeight]
/// (telefon mic sau text mărit). [minHeight] e înălțimea de care are nevoie conținutul la text normal;
/// se mărește proporțional cu textul.
class FillOrScroll extends StatelessWidget {
  const FillOrScroll({super.key, required this.padding, required this.minHeight, required this.child});

  final EdgeInsetsGeometry padding;
  final double minHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scaledMin = MediaQuery.textScalerOf(context).scale(minHeight);
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxHeight - padding.vertical;
        return SingleChildScrollView(
          padding: padding,
          physics: available >= scaledMin ? const NeverScrollableScrollPhysics() : null,
          child: SizedBox(height: available >= scaledMin ? available : scaledMin, child: child),
        );
      },
    );
  }
}

/// Cartonaș alb cu margine, folosit pentru fiecare bloc de pe ecran.
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.fromLTRB(20, 18, 20, 16)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    // Material (nu Container), ca butoanele și comutatoarele din cartonaș să-și arate efectul la apăsare.
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radius),
        side: BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    );
  }
}

/// Etichetă de secțiune cu majuscule (ex. „TREMOR”, „DEGETE”).
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(), style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.textMuted));
  }
}

/// Pastila de severitate: punct colorat + cuvânt.
class SeverityChip extends StatelessWidget {
  const SeverityChip(this.severity, {super.key});

  final Severity severity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(color: severity.background, borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: severity.dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            severity.label,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: severity.foreground),
          ),
        ],
      ),
    );
  }
}

/// Antetul ecranelor secundare: buton mare de înapoi + titlu.
class BackHeader extends StatelessWidget {
  const BackHeader({super.key, required this.title, this.subtitle, this.trailing, this.onBack});

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 56,
          height: 56,
          child: Material(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: AppColors.border),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onBack ?? () => Navigator.of(context).maybePop(),
              child: const Icon(Icons.arrow_back_ios_new_rounded, size: 24, semanticLabel: 'Înapoi'),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, height: 1.1)),
              if (subtitle != null) Text(subtitle!, style: TextStyle(fontSize: 17, color: AppColors.textMuted)),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Buton mare cu contur, pictogramă și o explicație sub titlu.
class OutlineBigButton extends StatelessWidget {
  const OutlineBigButton({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onPressed,
    this.centered = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onPressed;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        side: BorderSide(color: AppColors.borderStrong, width: 2),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      child: Row(
        mainAxisAlignment: centered ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.accent, size: 26),
          const SizedBox(width: 14),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: AppColors.textMuted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bandă galbenă care arată că datele sunt simulate.
class SimulatedBanner extends StatelessWidget {
  const SimulatedBanner(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1C7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6C766)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: Color(0xFF5C4300)),
      ),
    );
  }
}

/// Pastilă rotunjită din bara de sus (ex. starea conexiunii, alimentarea).
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: StadiumBorder(side: BorderSide(color: AppColors.border)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [Flexible(child: child)],
            ),
          ),
        ),
      ),
    );
  }
}
