import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/contract.dart';
import '../../core/format.dart';
import '../../core/glove_source.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/demo_seed.dart';
import '../../data/settings_store.dart';
import '../../state/providers.dart';
import '../calibrate/calibrate_screen.dart';
import '../connect/connect_screen.dart';
import '../connect/source_picker.dart';
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSizes.pagePadding, 14, AppSizes.pagePadding, 20),
      children: [
        Text(S.settingsTitle, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        const SectionLabel(S.gloveSection),
        const SizedBox(height: 8),
        _Group(
          children: [
            _NavRow(
              title: source.deviceName ?? 'Nicio mănușă aleasă',
              subtitle: gloveState,
              onTap: () => _open(context, const ConnectScreen()),
            ),
            _NavRow(
              title: S.calibration,
              subtitle:
                  '${S.lastCalibration} ${settings.lastCalibration == null ? S.neverCalibrated : Fmt.dayAndTime(settings.lastCalibration!)}',
              onTap: () => _open(context, const CalibrateScreen()),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const SectionLabel(S.alertsSection),
        const SizedBox(height: 8),
        _Group(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 10, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(S.alertThreshold, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                        Text(S.alertThresholdHint, style: TextStyle(fontSize: 16, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  _StepButton(
                    icon: Icons.remove,
                    label: S.decrease,
                    onPressed: () => setThreshold(settings.alertThreshold - AppSettings.thresholdStep),
                  ),
                  SizedBox(
                    width: 56,
                    child: Text(
                      '${settings.alertThreshold}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()]),
                    ),
                  ),
                  _StepButton(
                    icon: Icons.add,
                    label: S.increase,
                    onPressed: () => setThreshold(settings.alertThreshold + AppSettings.thresholdStep),
                  ),
                ],
              ),
            ),
            _SwitchRow(
              title: S.vibrateOnAlert,
              value: settings.vibrateOnAlert,
              onChanged: (v) => notifier.update((s) => s.copyWith(vibrateOnAlert: v)),
            ),
            _NavRow(
              title: S.testVibration,
              onTap: () {
                source.send(ControlCommand.vibrate, VibrationPattern.confirm);
                showMessage(source.isSimulated ? S.vibrationSimulated : S.vibrationSent);
              },
            ),
          ],
        ),
        const SizedBox(height: 14),
        const SectionLabel(S.appSection),
        const SizedBox(height: 8),
        _Group(
          children: [
            const Padding(padding: EdgeInsets.fromLTRB(18, 14, 18, 14), child: SourcePicker()),
            if (settings.demoMode)
              _NavRow(
                title: S.addDemoData,
                icon: Icons.add_chart,
                onTap: () async {
                  await addDemoWeek(ref.read(databaseProvider), threshold: settings.alertThreshold);
                  ref.invalidate(historyProvider);
                  showMessage(S.demoDataAdded);
                },
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(S.theme, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    style: SegmentedButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      textStyle: const TextStyle(fontFamily: 'Atkinson', fontSize: 16, fontWeight: FontWeight.w700),
                      selectedBackgroundColor: AppColors.accentSoft,
                      selectedForegroundColor: AppColors.accentDark,
                    ),
                    segments: const [
                      ButtonSegment(value: ThemeMode.system, label: Text(S.themeSystem)),
                      ButtonSegment(value: ThemeMode.light, label: Text(S.themeLight)),
                      ButtonSegment(value: ThemeMode.dark, label: Text(S.themeDark)),
                    ],
                    selected: {settings.themeMode},
                    onSelectionChanged: (v) => notifier.update((s) => s.copyWith(themeMode: v.first)),
                  ),
                ],
              ),
            ),
            _NavRow(title: S.instructions, onTap: () => _open(context, const InstructionsScreen())),
            _NavRow(title: S.about, subtitle: S.notMedicalDevice, onTap: () => _open(context, const AboutScreen())),
          ],
        ),
      ],
    );
  }
}

/// Grup de rânduri într-un cartonaș, cu linii subțiri între ele.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      clipBehavior: Clip.antiAlias,
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.radius),
        side: BorderSide(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[if (i > 0) Divider(height: 1, thickness: 1, color: AppColors.divider), children[i]],
        ],
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({required this.title, this.subtitle, required this.onTap, this.icon});

  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 14, 8),
          child: Row(
            children: [
              if (icon != null) ...[Icon(icon, color: AppColors.accent), const SizedBox(width: 12)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                    if (subtitle != null) Text(subtitle!, style: TextStyle(fontSize: 16, color: AppColors.textMuted)),
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

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({required this.title, required this.value, required this.onChanged});

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.fromLTRB(18, 4, 10, 4),
      title: Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
      value: value,
      onChanged: onChanged,
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      height: 56,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          side: BorderSide(color: AppColors.borderStrong, width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          foregroundColor: AppColors.text,
        ),
        child: Icon(icon, size: 26, semanticLabel: label),
      ),
    );
  }
}
