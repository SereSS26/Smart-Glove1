import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/glove_source.dart';
import '../../core/live_packet.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../state/providers.dart';
import '../calibrate/calibrate_screen.dart';
import '../connect/connect_screen.dart';
import '../session/session_screen.dart';
import 'sparkline.dart';

class LiveScreen extends ConsumerWidget {
  const LiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(liveProvider);
    final connection = ref.watch(connectionProvider).value ?? GloveConnection.disconnected;
    final simulated = ref.watch(gloveSourceProvider.select((s) => s.isSimulated));
    final sessionActive = ref.watch(sessionProvider) != null;
    final packet = live.stale ? null : live.packet;
    final canStart = connection == GloveConnection.connected && packet != null;

    return FillOrScroll(
      padding: const EdgeInsets.fromLTRB(AppSizes.pagePadding, 12, AppSizes.pagePadding, 12),
      minHeight: 720,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (simulated) ...[const SimulatedBanner(S.simulatedBanner), const SizedBox(height: 10)],
          _TopBar(connection: connection, stale: live.stale, packet: packet),
          const SizedBox(height: AppSizes.gap),
          _TremorCard(packet: packet, history: live.history),
          const SizedBox(height: AppSizes.gap),
          Expanded(child: _FingersCard(packet: packet)),
          const SizedBox(height: AppSizes.gap),
          FilledButton.icon(
            onPressed: canStart || sessionActive
                ? () async {
                    if (!sessionActive) await ref.read(sessionProvider.notifier).start();
                    if (context.mounted) Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SessionScreen()));
                  }
                : null,
            icon: Icon(sessionActive ? Icons.fiber_manual_record : Icons.play_arrow_rounded, size: 30),
            label: Text(sessionActive ? S.recording : S.startSession),
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
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.connection, required this.stale, required this.packet});

  final GloveConnection connection;
  final bool stale;
  final LivePacket? packet;

  @override
  Widget build(BuildContext context) {
    const label = TextStyle(fontSize: 17, fontWeight: FontWeight.w700);
    final (text, color) = switch (connection) {
      GloveConnection.connected when stale => (S.noData, AppColors.amber),
      GloveConnection.connected => (S.gloveConnected, AppColors.connected),
      GloveConnection.connecting => (S.gloveConnecting, AppColors.amber),
      GloveConnection.disconnected => (S.gloveDisconnected, AppColors.mutedDot),
    };
    final battery = packet?.batteryPercent;
    final lowBattery = battery != null && battery < 15;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: StatusPill(
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ConnectScreen())),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(text, style: label, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        if (packet != null)
          StatusPill(
            child: Row(
              children: [
                Icon(
                  packet!.onUsb ? Icons.power_outlined : (lowBattery ? Icons.battery_alert : Icons.battery_std),
                  size: 22,
                  color: lowBattery ? AppColors.recording : null,
                ),
                const SizedBox(width: 6),
                Text(packet!.onUsb ? S.powerUsb : '$battery %', style: label.copyWith(color: lowBattery ? AppColors.recording : null)),
              ],
            ),
          ),
      ],
    );
  }
}

class _TremorCard extends StatelessWidget {
  const _TremorCard({required this.packet, required this.history});

  final LivePacket? packet;
  final List<double> history;

  @override
  Widget build(BuildContext context) {
    final muted = TextStyle(fontSize: 16, color: AppColors.textMuted);
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
                  Text(S.noData, style: muted.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Cu text mărit, cifrele mari se micșorează cât să încapă pe rând.
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.bottomLeft,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        if (p != null && p.hasTremor)
                          Text(Fmt.hz(p.frequencyHz), style: const TextStyle(fontSize: 72, fontWeight: FontWeight.w700, height: 1))
                        else
                          // Fără tremor sau fără date: o liniuță discretă, nu o cifră mare.
                          Text(
                            '–',
                            style: TextStyle(fontSize: 56, fontWeight: FontWeight.w700, height: 1.28, color: AppColors.textMuted),
                          ),
                        const SizedBox(width: 8),
                        if (p != null && p.hasTremor)
                          Text(
                            'Hz',
                            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.textMuted),
                          )
                        else if (p != null)
                          Text(
                            S.noTremor,
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textMuted),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(S.index, style: muted),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          p == null ? '—' : '${p.tremorIndex}',
                          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w700, height: 1),
                        ),
                        Text('/100', style: muted.copyWith(fontSize: 17)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Sparkline(values: history),
            const SizedBox(height: 8),
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
                          style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700),
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
  const _FingersCard({required this.packet});

  final LivePacket? packet;

  @override
  Widget build(BuildContext context) {
    final p = packet;
    final calibrated = p != null && p.fingers.any((f) => f != null);
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
                Text(S.bendPercent, style: TextStyle(fontSize: 16, color: AppColors.textMuted)),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: p != null && !calibrated
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(S.fingersNotCalibrated, textAlign: TextAlign.center, style: TextStyle(fontSize: 19)),
                        const SizedBox(height: 12),
                        OutlineBigButton(
                          icon: Icons.back_hand_outlined,
                          title: S.calibrateNow,
                          centered: true,
                          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CalibrateScreen())),
                        ),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < S.fingerNames.length; i++) ...[
                          if (i > 0) const SizedBox(width: 12),
                          Expanded(
                            child: _FingerBar(name: S.fingerNames[i], percent: p?.fingers[i]),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FingerBar extends StatelessWidget {
  const _FingerBar({required this.name, required this.percent});

  final String name;
  final int? percent;

  @override
  Widget build(BuildContext context) {
    final value = percent;
    return Semantics(
      label: value == null ? '$name: fără date' : '$name: $value la sută îndoit',
      excludeSemantics: true,
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              alignment: Alignment.bottomCenter,
              decoration: BoxDecoration(color: AppColors.track, borderRadius: BorderRadius.circular(10)),
              child: FractionallySizedBox(
                heightFactor: (value ?? 0).clamp(0, 100) / 100,
                widthFactor: 1,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  decoration: BoxDecoration(color: AppColors.fingerBar, borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(value == null ? '—' : '$value', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.1)),
          // Numele lungi (Arătător, Mijlociu) se micșorează ca să nu se atingă cu text mărit.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(name, style: TextStyle(fontSize: 15, color: AppColors.textMuted), maxLines: 1, softWrap: false),
          ),
        ],
      ),
    );
  }
}
