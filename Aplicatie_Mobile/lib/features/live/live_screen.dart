import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../app.dart';
import '../../core/format.dart';
import '../../core/glove_source.dart';
import '../../core/live_packet.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/settings_store.dart';
import '../../state/providers.dart';
import '../../ui/ui.dart';
import '../calibrate/calibrate_screen.dart';
import '../settings/account_widgets.dart';
import '../connect/connect_screen.dart';
import '../session/session_screen.dart';
import '../tests/test_picker_screen.dart';

class LiveScreen extends ConsumerWidget {
  const LiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(liveProvider);
    final connection = ref.watch(connectionProvider).value ?? GloveConnection.disconnected;
    final simulated = ref.watch(gloveSourceProvider.select((s) => s.isSimulated));
    final threshold = ref.watch(settingsProvider.select((s) => s.alertThreshold));
    final sessionActive = ref.watch(sessionProvider) != null;
    final packet = live.stale ? null : live.packet;
    final canStart = connection == GloveConnection.connected && packet != null;

    // Live are mai mult conținut decât un ecran: se derulează (fără să ascundă butonul principal sus).
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSizes.pagePadding, 12, AppSizes.pagePadding, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (simulated) ...[const SimulatedBanner(S.simulatedBanner), const SizedBox(height: 10)],
          const _Greeting(),
          const SizedBox(height: AppSizes.gap),
          _GloveCard(connection: connection, stale: live.stale, packet: packet),
          const SizedBox(height: AppSizes.gap),
          GradientButton(
            label: sessionActive ? S.recordingNow : S.startSession,
            icon: sessionActive ? Symbols.fiber_manual_record_rounded : Symbols.play_arrow_rounded,
            danger: sessionActive,
            // Sesiune nouă: alegi testele; o înregistrare în curs se deschide direct.
            onPressed: () =>
                Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => sessionActive ? const SessionScreen() : const TestPickerScreen())),
          ),
          if (!canStart && !sessionActive)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                S.connectFirst,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: AppColors.textMuted),
              ),
            ),
          const SizedBox(height: AppSizes.gap),
          _TremorCard(packet: packet, history: live.history, threshold: threshold),
          const SizedBox(height: AppSizes.gap),
          _FingersCard(packet: packet, history: live.fingerHistory),
        ],
      ),
    );
  }
}

/// Salutul de sus: „Bună, Ion”, data și inițialele (duc la Setări).
class _Greeting extends ConsumerWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user == null ? 'Bună' : 'Bună, ${user.shortName}',
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.15),
              ),
              Text(Fmt.weekdayDate(DateTime.now()), style: TextStyle(fontSize: 15, color: AppColors.textMuted)),
            ],
          ),
        ),
        if (user != null)
          Semantics(
            button: true,
            label: 'Profil și setări',
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => ref.read(patientTabProvider.notifier).go(Tabs.settings),
              child: Avatar(initials: user.initials),
            ),
          ),
      ],
    );
  }
}

/// Cardul Mănușa: starea conexiunii, alegerea USB / Wi-Fi / Demo și calibrarea.
class _GloveCard extends ConsumerWidget {
  const _GloveCard({required this.connection, required this.stale, required this.packet});

  final GloveConnection connection;
  final bool stale;
  final LivePacket? packet;

  void _open(BuildContext context, Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final source = settings.source;
    final needsWifi = source == DataSource.wifi && (settings.wifiHost == null || settings.wifiHost!.isEmpty);
    final p = packet;
    final power = p == null ? '' : (p.onUsb ? ' · USB' : ' · ${p.batteryPercent} %');
    final lowBattery = p != null && !p.onUsb && (p.batteryPercent ?? 100) < 15;
    final (text, bg, fg, dot) = switch (connection) {
      _ when needsWifi => ('alege mănușa', AppColors.warningBg, AppColors.warningFg, AppColors.mod),
      _ when source == DataSource.demo => ('date simulate', AppColors.warningBg, AppColors.warningFg, AppColors.mod),
      GloveConnection.connected when stale => (S.noData.toLowerCase(), AppColors.warningBg, AppColors.warningFg, AppColors.mod),
      GloveConnection.connected => (
        'conectată$power',
        lowBattery ? AppColors.badBg : AppColors.okBg,
        lowBattery ? AppColors.badFg : AppColors.okFg,
        lowBattery ? AppColors.bad : AppColors.ok,
      ),
      GloveConnection.connecting => (S.gloveConnecting.toLowerCase(), AppColors.warningBg, AppColors.warningFg, AppColors.mod),
      GloveConnection.disconnected => ('deconectată', AppColors.track, AppColors.textMuted, AppColors.mutedDot),
    };
    final calibration = settings.lastCalibration == null ? S.neverCalibrated : Fmt.dayAndTime(settings.lastCalibration!);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: SectionLabel('Mănușa')),
              Semantics(
                button: true,
                label: 'Starea mănușii: $text. Deschide conectarea.',
                excludeSemantics: true,
                child: Material(
                  color: bg,
                  shape: const StadiumBorder(),
                  child: InkWell(
                    customBorder: const StadiumBorder(),
                    onTap: () => _open(context, const ConnectScreen()),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 40),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              text,
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: fg),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ChoiceTiles<DataSource>(
            options: const [
              Choice(DataSource.usb, 'USB', icon: Symbols.usb_rounded),
              Choice(DataSource.wifi, 'Wi-Fi', icon: Symbols.wifi_rounded),
              Choice(DataSource.demo, 'Demo', icon: Symbols.auto_awesome_rounded),
            ],
            selected: source,
            onChanged: (v) => ref.read(settingsProvider.notifier).update((s) => s.copyWith(source: v)),
          ),
          const SizedBox(height: 10),
          if (needsWifi)
            OutlineBigButton(
              icon: Symbols.wifi_find_rounded,
              title: 'Caută mănușa în rețea',
              subtitle: 'sau scrie adresa ei',
              onPressed: () => _open(context, const ConnectScreen()),
            )
          else
            OutlineBigButton(
              icon: Symbols.back_hand_rounded,
              title: 'Calibrează mănușa',
              subtitle: source == DataSource.demo ? 'mănușa simulată e deja calibrată' : 'ultima calibrare: $calibration',
              onPressed: () => _open(context, const CalibrateScreen()),
            ),
        ],
      ),
    );
  }
}

class _TremorCard extends StatelessWidget {
  const _TremorCard({required this.packet, required this.history, required this.threshold});

  final LivePacket? packet;
  final List<double> history;
  final int threshold;

  @override
  Widget build(BuildContext context) {
    final muted = TextStyle(fontSize: 15, color: AppColors.textMuted);
    final p = packet;
    return Opacity(
      opacity: p == null ? 0.45 : 1,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SectionLabel(S.tremor),
                if (p != null)
                  SeverityChip(Severity.fromIndex(p.tremorIndex))
                else
                  Text(S.noData, style: muted.copyWith(fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                TremorRing(index: p?.tremorIndex, threshold: threshold, size: 96),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Cu text mărit, cifrele mari se micșorează cât să încapă pe rând.
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            if (p != null && p.hasTremor) ...[
                              Text(
                                Fmt.hz(p.frequencyHz),
                                style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w800, height: 1, fontFeatures: tabular),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Hz',
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textMuted),
                              ),
                            ] else
                              // Fără tremor sau fără date: o liniuță discretă, nu o cifră mare.
                              Text(
                                p == null ? '–' : S.noTremor,
                                style: TextStyle(
                                  fontSize: p == null ? 44 : 22,
                                  fontWeight: FontWeight.w800,
                                  height: 1.1,
                                  color: AppColors.textMuted,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text('frecvența tremorului', style: muted),
                      Text.rich(
                        TextSpan(
                          text: 'pragul tău: ',
                          style: muted.copyWith(color: AppColors.text, fontWeight: FontWeight.w700),
                          children: [
                            TextSpan(
                              text: '$threshold',
                              style: TextStyle(color: AppColors.recording),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TrendChart(values: history, threshold: threshold, height: 64),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(child: Text(S.last30s, style: muted)),
                const SizedBox(width: 12),
                if (p != null)
                  Text.rich(
                    TextSpan(
                      text: '${S.stateLabel} ',
                      style: muted,
                      children: [
                        TextSpan(
                          text: p.state.label,
                          style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FingersCard extends StatelessWidget {
  const _FingersCard({required this.packet, required this.history});

  final LivePacket? packet;
  final List<List<int?>> history;

  @override
  Widget build(BuildContext context) {
    final p = packet;
    final calibrated = p != null && p.fingers.any((f) => f != null);
    final fingers = p?.fingers ?? List<int?>.filled(S.fingerNames.length, null);
    return Opacity(
      opacity: p == null ? 0.45 : 1,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SectionLabel(S.fingers),
                Text(S.bendPercent, style: TextStyle(fontSize: 15, color: AppColors.textMuted)),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              child: p != null && !calibrated
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(S.fingersNotCalibrated, textAlign: TextAlign.center, style: TextStyle(fontSize: 19)),
                        const SizedBox(height: 12),
                        OutlineBigButton(
                          icon: Symbols.back_hand_rounded,
                          title: S.calibrateNow,
                          centered: true,
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CalibrateScreen())),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            LiveHand(fingers: fingers, width: 100),
                            const SizedBox(width: 16),
                            Expanded(child: _FingerList(fingers: fingers)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        FingerChart(history: history, height: 36),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lista degetelor: punctul de aceeași culoare ca pe mână, numele și procentul.
class _FingerList extends StatelessWidget {
  const _FingerList({required this.fingers});

  final List<int?> fingers;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < S.fingerNames.length; i++)
          Semantics(
            label: fingers[i] == null ? '${S.fingerNames[i]}: necalibrat' : '${S.fingerNames[i]}: ${fingers[i]} la sută îndoit',
            excludeSemantics: true,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: fingers[i] == null ? null : fingerColor(i),
                      border: fingers[i] == null ? Border.all(color: AppColors.textMuted, width: 2) : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      S.fingerNames[i],
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 16, color: fingers[i] == null ? AppColors.textMuted : AppColors.text),
                    ),
                  ),
                  Text(
                    fingers[i] == null ? '—' : '${fingers[i]} %',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      fontFeatures: tabular,
                      color: fingers[i] == null ? AppColors.textMuted : AppColors.text,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
