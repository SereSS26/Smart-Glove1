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

/// Cartonaș alb cu colțuri de 24 și umbră moale rozalie (pe tema întunecată: margine fină).
class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.color});

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    // Material (nu Container), ca butoanele și comutatoarele din cartonaș să-și arate efectul la apăsare.
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppSizes.radius), boxShadow: AppShadows.card),
      child: Material(
        color: color ?? AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.radius),
          side: BorderSide(color: AppColors.cardBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Etichetă de secțiune cu majuscule rărite (ex. „TREMOR”, „DEGETE”).
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
  const SeverityChip(this.severity, {super.key, this.prefix});

  final Severity severity;

  /// Text înaintea cuvântului (ex. indicele: „48 · moderat”).
  final String? prefix;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(color: severity.background, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: severity.dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              prefix == null ? severity.label : '$prefix · ${severity.label}',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: severity.foreground, fontFeatures: tabular),
            ),
          ),
        ],
      ),
    );
  }
}

/// Antetul ecranelor secundare: buton mare de înapoi + titlu.
class BackHeader extends StatelessWidget {
  const BackHeader({super.key, required this.title, this.subtitle, this.trailing, this.onBack, this.showBack = true});

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onBack;

  /// Fără butonul înapoi (ex. detaliul din dreapta, pe tabletă).
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (showBack) ...[
          SizedBox(
            width: 52,
            height: 52,
            child: Material(
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppColors.border),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onBack ?? () => Navigator.of(context).maybePop(),
                child: Icon(Icons.arrow_back_rounded, size: 26, color: AppColors.text, semanticLabel: 'Înapoi'),
              ),
            ),
          ),
          const SizedBox(width: 14),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.15)),
              if (subtitle != null) Text(subtitle!, style: TextStyle(fontSize: 16, color: AppColors.textMuted)),
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Buton mare cu contur, iconiță pe fond roz pal și o explicație sub titlu.
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
    final enabled = onPressed != null;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
        padding: const EdgeInsets.fromLTRB(10, 8, 16, 8),
        side: BorderSide(color: AppColors.border, width: 2),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      child: Row(
        mainAxisAlignment: centered ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: enabled ? AppColors.accentSoft : AppColors.track, borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, color: enabled ? AppColors.accentDark : AppColors.textMuted, size: 24),
          ),
          const SizedBox(width: 14),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: enabled ? AppColors.text : AppColors.textMuted),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: AppColors.textMuted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bandă care arată că datele sunt simulate.
class SimulatedBanner extends StatelessWidget {
  const SimulatedBanner(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warningBorder),
      ),
      child: Text(
        text.toUpperCase(),
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.9, color: AppColors.warningFg),
      ),
    );
  }
}

/// Pastilă rotunjită din bara de sus (ex. starea conexiunii, alimentarea).
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.child, this.onTap, this.color});

  final Widget child;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color ?? AppColors.surface,
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
