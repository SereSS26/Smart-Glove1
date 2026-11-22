import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/settings_store.dart';
import '../../state/providers.dart';
import '../../ui/ui.dart';
import '../calibrate/calibrate_screen.dart';
import '../connect/connect_screen.dart';

/// Prima pornire: avertisment → conectare (sau date simulate) → calibrare → ecranul principal.
class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  void _finish(WidgetRef ref) {
    ref.read(settingsProvider.notifier).update((s) => s.copyWith(onboardingDone: true));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> start({required bool demo}) async {
      await ref.read(notificationsProvider).requestPermission();
      ref.read(settingsProvider.notifier).update((s) => s.copyWith(source: demo ? DataSource.demo : DataSource.usb));
      if (!context.mounted) return;
      if (demo) {
        // Mănușa simulată e deja calibrată; se intră direct în aplicație.
        _finish(ref);
        return;
      }
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (c) => ConnectScreen(
            onContinue: () => Navigator.of(c).push(
              MaterialPageRoute<void>(
                builder: (_) => CalibrateScreen(
                  onDone: () {
                    Navigator.of(c).popUntil((r) => r.isFirst);
                    _finish(ref);
                  },
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSizes.pagePadding, 28, AppSizes.pagePadding, 24),
          children: [
            const Center(child: AppMark(size: 92)),
            const SizedBox(height: 18),
            Text(S.welcomeTitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 10),
            const Text(S.welcomeBody, textAlign: TextAlign.center, style: TextStyle(fontSize: 19, height: 1.4)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.warningBg,
                borderRadius: BorderRadius.circular(AppSizes.radius),
                border: Border.all(color: AppColors.warningBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Symbols.info_rounded, color: AppColors.warningFg),
                      SizedBox(width: 10),
                      Text(
                        S.disclaimerTitle,
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.warningFg),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(S.disclaimerBody, style: TextStyle(fontSize: 18, height: 1.4, color: AppColors.warningFg)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(S.dataStaysLocal, style: TextStyle(fontSize: 17, color: AppColors.textMuted)),
            const SizedBox(height: 24),
            GradientButton(label: S.haveGlove, icon: Symbols.back_hand_rounded, onPressed: () => start(demo: false)),
            const SizedBox(height: 10),
            OutlineBigButton(icon: Symbols.auto_awesome_rounded, title: S.tryDemo, centered: true, onPressed: () => start(demo: true)),
          ],
        ),
      ),
    );
  }
}
