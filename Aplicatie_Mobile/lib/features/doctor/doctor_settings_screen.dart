import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../state/providers.dart';
import '../../ui/ui.dart';
import '../settings/account_widgets.dart';
import '../settings/info_screens.dart';
import 'doctor_prefs.dart';
import 'weekly_summary.dart';

/// Setările medicului: profil, notificări, exportul implicit, tema, ieșirea din cont.
class DoctorSettingsScreen extends ConsumerWidget {
  const DoctorSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    final settings = ref.watch(settingsProvider);
    final prefs = ref.watch(doctorPrefsProvider);
    final notifier = ref.read(doctorPrefsProvider.notifier);
    Widget label(String text) => Padding(padding: const EdgeInsets.fromLTRB(4, 18, 4, 8), child: SectionLabel(text));

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSizes.pagePadding, 14, AppSizes.pagePadding, 24),
      children: [
        Text(S.settingsTitle, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        if (user != null) ProfileCard(user: user),
        label('Notificări'),
        SettingsGroup(
          children: [
            SwitchRow(
              title: 'Rezumatul săptămânal',
              subtitle: 'luni, la 09:00 · pacienții de urmărit',
              value: prefs.weeklySummary,
              onChanged: (v) {
                notifier.update((p) => p.copyWith(weeklySummary: v));
                syncWeeklySummary(ref);
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Symbols.info_rounded, size: 20, color: AppColors.textMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Alertele imediate despre pacienți apar după conectarea aplicației la server.',
                      style: TextStyle(fontSize: 15, color: AppColors.textMuted, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        label('Export'),
        SettingsGroup(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Format implicit', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  AppSegmented<bool>(
                    options: const [Choice(true, 'PDF'), Choice(false, 'CSV')],
                    selected: prefs.pdf,
                    onChanged: (v) => notifier.update((p) => p.copyWith(pdf: v)),
                  ),
                  const SizedBox(height: 14),
                  const Text('Perioada implicită', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  AppSegmented<int>(
                    options: const [Choice(7, '7 zile'), Choice(30, '30 zile'), Choice(90, '90 zile')],
                    selected: prefs.days,
                    onChanged: (v) => notifier.update((p) => p.copyWith(days: v)),
                  ),
                ],
              ),
            ),
          ],
        ),
        label('Aspect'),
        SettingsGroup(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(S.theme, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  AppSegmented<ThemeMode>(
                    options: const [
                      Choice(ThemeMode.system, S.themeSystem),
                      Choice(ThemeMode.light, S.themeLight),
                      Choice(ThemeMode.dark, S.themeDark),
                    ],
                    selected: settings.themeMode,
                    onChanged: (v) => ref.read(settingsProvider.notifier).update((s) => s.copyWith(themeMode: v)),
                  ),
                ],
              ),
            ),
            NavRow(
              icon: Symbols.info_rounded,
              title: 'Despre aplicație',
              subtitle: S.notMedicalDevice,
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AboutScreen())),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const LogoutButton(),
      ],
    );
  }
}
