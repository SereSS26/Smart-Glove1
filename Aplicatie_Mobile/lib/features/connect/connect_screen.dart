import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/glove_source.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/ble_glove.dart';
import '../../data/settings_store.dart';
import '../../state/providers.dart';
import 'source_picker.dart';

/// Căutarea și conectarea mănușii; tot aici se pornește modul demonstrativ.
/// [onContinue] e folosit la prima pornire, ca să treacă la calibrare.
class ConnectScreen extends ConsumerStatefulWidget {
  const ConnectScreen({super.key, this.onContinue});

  final VoidCallback? onContinue;

  @override
  ConsumerState<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends ConsumerState<ConnectScreen> {
  final _found = <String, FoundGlove>{};
  StreamSubscription<FoundGlove>? _scan;
  StreamSubscription<BleStatus>? _statusSub;
  BleStatus _status = BleStatus.unknown;
  bool _scanning = false;
  bool _permissionDenied = false;
  bool _asking = false;

  @override
  void initState() {
    super.initState();
    if (ref.read(settingsProvider).source == DataSource.ble) _startBle();
  }

  @override
  void dispose() {
    _scan?.cancel();
    _statusSub?.cancel();
    super.dispose();
  }

  Future<bool> _askPermissions() async {
    if (!Platform.isAndroid) return (await Permission.bluetooth.request()).isGranted;
    // Android 12+ (SDK 31) are permisiuni de Bluetooth separate; locația se cere doar pe Android 11 și mai vechi.
    final sdk = (await DeviceInfoPlugin().androidInfo).version.sdkInt;
    final needed = sdk >= 31 ? [Permission.bluetoothScan, Permission.bluetoothConnect] : [Permission.locationWhenInUse];
    final results = await needed.request();
    return needed.every((p) => results[p]?.isGranted ?? false);
  }

  Future<void> _startBle() async {
    // Întâi permisiunile, apoi starea Bluetooth: altfel ecranul ar arăta „fără permisiune”
    // cât timp utilizatorul încă citește cererea.
    setState(() => _asking = true);
    final granted = await _askPermissions();
    if (!mounted) return;
    setState(() {
      _asking = false;
      _permissionDenied = !granted;
    });
    if (!granted) return;
    _statusSub ??= ref.read(scannerProvider).status.listen((s) {
      if (mounted) setState(() => _status = s);
      if (s == BleStatus.ready && !_scanning) _startScan();
    });
    if (_status == BleStatus.ready) _startScan();
  }

  void _startScan() {
    _scan?.cancel();
    setState(() {
      _found.clear();
      _scanning = true;
    });
    _scan = ref
        .read(scannerProvider)
        .scan()
        .listen(
          (g) {
            if (mounted) setState(() => _found[g.id] = g);
          },
          onError: (_) {
            if (mounted) setState(() => _scanning = false);
          },
        );
    // Scanarea consumă baterie; se oprește după 15 secunde.
    Timer(const Duration(seconds: 15), () {
      _scan?.cancel();
      if (mounted) setState(() => _scanning = false);
    });
  }

  Future<void> _connect(FoundGlove g) async {
    _scan?.cancel();
    ref.read(settingsProvider.notifier).update((s) => s.copyWith(lastDeviceId: g.id, lastDeviceName: g.name));
    await ref.read(gloveSourceProvider).connect(g.id, name: g.name);
  }

  void _onSourceChanged(DataSource source) {
    if (source == DataSource.ble) {
      _startBle();
    } else {
      _scan?.cancel();
      setState(() => _scanning = false);
    }
  }

  String? _problem() {
    if (_asking) return null;
    if (_permissionDenied) return S.bluetoothNoPermission;
    return switch (_status) {
      BleStatus.unsupported => S.bluetoothUnsupported,
      BleStatus.poweredOff => S.bluetoothOff,
      BleStatus.unauthorized => S.bluetoothNoPermission,
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final kind = ref.watch(settingsProvider.select((s) => s.source));
    final source = ref.watch(gloveSourceProvider);
    final connection = ref.watch(connectionProvider).value ?? GloveConnection.disconnected;
    final problem = kind == DataSource.ble ? _problem() : null;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSizes.pagePadding, 16, AppSizes.pagePadding, 20),
          children: [
            BackHeader(title: S.connectTitle, onBack: widget.onContinue == null ? null : () => Navigator.of(context).maybePop()),
            const SizedBox(height: 14),
            AppCard(child: SourcePicker(onChanged: _onSourceChanged)),
            const SizedBox(height: 14),
            if (connection == GloveConnection.connected || kind != DataSource.usb) ...[
              if (connection != GloveConnection.disconnected) ...[
                _CurrentGlove(name: source.deviceName ?? '', connection: connection, simulated: source.isSimulated),
                const SizedBox(height: 14),
              ],
            ],
            if (kind == DataSource.usb) ...[_UsbHelp(connected: connection == GloveConnection.connected), const SizedBox(height: 14)],
            if (kind == DataSource.ble) ...[
              _StatusBox(ok: problem == null, text: problem ?? (_asking ? S.checkingBluetooth : (_scanning ? S.searching : S.bluetoothOn))),
              const SizedBox(height: 14),
              const SectionLabel(S.foundGloves),
              const SizedBox(height: 10),
              if (_found.isEmpty)
                Text(S.noGloves, style: TextStyle(fontSize: 18, color: AppColors.textMuted))
              else
                for (final g in _found.values) ...[_FoundTile(glove: g, onConnect: () => _connect(g)), const SizedBox(height: 10)],
              const SizedBox(height: 4),
              OutlineBigButton(
                icon: Icons.refresh_rounded,
                title: S.searchAgain,
                centered: true,
                onPressed: problem == null && !_scanning ? _startScan : null,
              ),
              const SizedBox(height: 10),
              Text(S.keepClose, style: TextStyle(fontSize: 17, color: AppColors.textMuted)),
              const SizedBox(height: 18),
            ],
            if (widget.onContinue != null) ...[
              const SizedBox(height: 20),
              FilledButton(
                onPressed: connection == GloveConnection.connected ? widget.onContinue : null,
                child: const Text(S.continueLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CurrentGlove extends StatelessWidget {
  const _CurrentGlove({required this.name, required this.connection, required this.simulated});

  final String name;
  final GloveConnection connection;
  final bool simulated;

  @override
  Widget build(BuildContext context) {
    final connected = connection == GloveConnection.connected;
    return AppCard(
      child: Row(
        children: [
          Icon(connected ? Icons.check_circle : Icons.sync, color: connected ? AppColors.connected : AppColors.amber, size: 30),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
                Text(
                  connected ? (simulated ? 'conectată · date simulate' : 'conectată') : S.gloveConnecting,
                  style: TextStyle(fontSize: 16, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBox extends StatelessWidget {
  const _StatusBox({required this.ok, required this.text});

  final bool ok;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(color: ok ? AppColors.accentSoft : AppColors.warningBg, borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          Icon(ok ? Icons.bluetooth : Icons.bluetooth_disabled, color: ok ? AppColors.accentDark : AppColors.warningFg, size: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: ok ? AppColors.accentDark : AppColors.warningFg),
            ),
          ),
        ],
      ),
    );
  }
}

class _FoundTile extends StatelessWidget {
  const _FoundTile({required this.glove, required this.onConnect});

  final FoundGlove glove;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    final bars = glove.rssi > -60 ? 3 : (glove.rssi > -75 ? 2 : 1);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(glove.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              ),
              Semantics(
                label: 'Semnal: $bars din 3',
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 1; i <= 3; i++)
                      Container(
                        width: 8,
                        height: 8.0 + i * 8,
                        margin: const EdgeInsets.only(left: 4),
                        decoration: BoxDecoration(
                          color: i <= bars ? AppColors.accent : AppColors.track,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton(onPressed: onConnect, child: const Text(S.connect)),
        ],
      ),
    );
  }
}

/// Pașii pentru mănușa legată prin USB la calculator, cu starea legăturii.
class _UsbHelp extends StatelessWidget {
  const _UsbHelp({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(connected ? Icons.usb_rounded : Icons.sync, color: connected ? AppColors.connected : AppColors.amber, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(connected ? S.usbConnected : S.usbWaiting, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          if (!connected) ...[
            const SizedBox(height: 12),
            for (var i = 0; i < S.usbSteps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('${i + 1}. ${S.usbSteps[i]}', style: const TextStyle(fontSize: 17)),
              ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.track, borderRadius: BorderRadius.circular(10)),
              child: SelectableText(S.usbCommand, style: const TextStyle(fontFamily: 'monospace', fontSize: 14)),
            ),
          ],
        ],
      ),
    );
  }
}
