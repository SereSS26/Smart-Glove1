import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../app.dart';
import '../../core/contract.dart';
import '../../core/format.dart';
import '../../core/glove_source.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/demo_seed.dart';
import '../../data/settings_store.dart';
import '../../services/feedback.dart';
import '../../state/providers.dart';
import '../../state/reminder_providers.dart';
import '../../ui/gallery_screen.dart';
import '../../ui/ui.dart';
import '../calibrate/calibrate_screen.dart';
import '../connect/connect_screen.dart';
import '../connect/source_picker.dart';
import 'account_widgets.dart';
import 'info_screens.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _open(BuildContext context, Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final source = ref.watch(gloveSourceProvider);
    final connection = ref.watch(connectionProvider).value ?? GloveConnection.disconnected;
    final packet = ref.watch(liveProvider.select((l) => l.stale ? null : l.packet));
    final notifier = ref.read(settingsProvider.notifier);
    final user = ref.watch(authProvider);

    void setThreshold(int value) {
      final v = value.clamp(AppSettings.minThreshold, AppSettings.maxThreshold);
      notifier.update((s) => s.copyWith(alertThreshold: v));
      source.send(ControlCommand.alertThreshold, v);
    }

    final gloveState = switch (connection) {
      GloveConnection.connected =>
        packet == null ? 'conectată · fără date' : 'conectată · ${packet.onUsb ? 'USB' : '${packet.batteryPercent} %'}',
      GloveConnection.connecting => S.gloveConnecting.toLowerCase(),
      GloveConnection.disconnected => 'deconectată',
    };

    final remPrefs = ref.watch(reminderPrefsProvider);
    Widget label(String text) => Padding(padding: const EdgeInsets.fromLTRB(4, 18, 4, 8), child: SectionLabel(text));

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSizes.pagePadding, 14, AppSizes.pagePadding, 24),
      children: [
        Text(S.settingsTitle, style: Theme.of(context).textTheme.headlineMedium),
        if (user != null) ...[const SizedBox(height: 12), ProfileCard(user: user)],
        label(S.gloveSection),
        SettingsGroup(
          children: [
            NavRow(
              icon: Symbols.back_hand_rounded,
              title: source.deviceName ?? 'Nicio mănușă aleasă',
              subtitle: gloveState,
              onTap: () => _open(context, const ConnectScreen()),
            ),
            NavRow(
              icon: Symbols.tune_rounded,
              title: S.calibration,
              subtitle:
                  '${S.lastCalibration} ${settings.lastCalibration == null ? S.neverCalibrated : Fmt.dayAndTime(settings.lastCalibration!)}',
              onTap: () => _open(context, const CalibrateScreen()),
            ),
            const Padding(padding: EdgeInsets.fromLTRB(16, 14, 16, 16), child: SourcePicker()),
          ],
        ),
        label(S.alertsSection),
        SettingsGroup(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(S.alertThreshold, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        Text(S.alertThresholdHint, style: TextStyle(fontSize: 15, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  StepperField(
                    value: '${settings.alertThreshold}',
                    minusLabel: S.decrease,
                    plusLabel: S.increase,
                    onMinus: () => setThreshold(settings.alertThreshold - AppSettings.thresholdStep),
                    onPlus: () => setThreshold(settings.alertThreshold + AppSettings.thresholdStep),
                  ),
                ],
              ),
            ),
            SwitchRow(
              title: S.vibrateOnAlert,
              subtitle: 'mănușa vibrează când treci de prag',
              value: settings.vibrateOnAlert,
              onChanged: (v) => notifier.update((s) => s.copyWith(vibrateOnAlert: v)),
            ),
            NavRow(
              icon: Symbols.vibration_rounded,
              title: S.testVibration,
              onTap: () {
                source.send(ControlCommand.vibrate, VibrationPattern.confirm);
                showMessage(source.isSimulated ? S.vibrationSimulated : S.vibrationSent);
              },
            ),
          ],
        ),
        label('Notificări'),
        SettingsGroup(
          children: [
            SwitchRow(
              title: 'Medicamente',
              subtitle: 'la ora fiecărei doze, cu „Am luat” și „Amână”',
              value: remPrefs.meds,
              onChanged: (v) => ref.read(reminderPrefsProvider.notifier).update((p) => p.copyWith(meds: v)),
            ),
            SwitchRow(
              title: 'Testul zilnic',
              subtitle: 'la ora din reminderul de test',
              value: remPrefs.tests,
              onChanged: (v) => ref.read(reminderPrefsProvider.notifier).update((p) => p.copyWith(tests: v)),
            ),
            SwitchRow(
              title: 'Stoc mic',
              subtitle: 'când un medicament mai ajunge pentru puține zile',
              value: remPrefs.stock,
              onChanged: (v) => ref.read(reminderPrefsProvider.notifier).update((p) => p.copyWith(stock: v)),
            ),
          ],
        ),
        label(S.appSection),
        SettingsGroup(
          children: [
            SwitchRow(
              title: 'Vibrație la apăsare',
              subtitle: 'un puls scurt confirmă fiecare apăsare',
              value: ref.watch(hapticsProvider),
              onChanged: (v) => ref.read(hapticsProvider.notifier).set(v),
            ),
            SwitchRow(
              title: 'Ghidare vocală în teste',
              subtitle: 'telefonul citește instrucțiunile cu voce',
              value: ref.watch(voiceGuideEnabledProvider),
              onChanged: (v) => ref.read(voiceGuideEnabledProvider.notifier).set(v),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(S.theme, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  AppSegmented<ThemeMode>(
                    options: const [
                      Choice(ThemeMode.system, S.themeSystem),
                      Choice(ThemeMode.light, S.themeLight),
                      Choice(ThemeMode.dark, S.themeDark),
                    ],
                    selected: settings.themeMode,
                    onChanged: (v) => notifier.update((s) => s.copyWith(themeMode: v)),
                  ),
                ],
              ),
            ),
            if (settings.demoMode)
              NavRow(
                title: S.addDemoData,
                icon: Symbols.add_chart_rounded,
                onTap: () async {
                  showMessage('Pregătesc 3 luni de date demo…');
                  await addDemoMonths(ref.read(databaseProvider), threshold: settings.alertThreshold);
                  ref.invalidate(historyProvider);
                  showMessage(S.demoDataAdded);
                },
              ),
            NavRow(icon: Symbols.menu_book_rounded, title: S.instructions, onTap: () => _open(context, const InstructionsScreen())),
            NavRow(
              icon: Symbols.info_rounded,
              title: S.about,
              subtitle: S.notMedicalDevice,
              onTap: () => _open(context, const AboutScreen()),
            ),
            if (kDebugMode)
              NavRow(
                icon: Symbols.widgets_rounded,
                title: S.gallery,
                subtitle: S.galleryHint,
                onTap: () => _open(context, const GalleryScreen()),
              ),
          ],
        ),
        const SizedBox(height: 20),
        const LogoutButton(),
      ],
    );
  }
}
