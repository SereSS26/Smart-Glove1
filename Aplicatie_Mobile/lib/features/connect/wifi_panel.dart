import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../app.dart';
import '../../core/glove_source.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/usb_glove.dart';
import '../../data/wifi_finder.dart';
import '../../state/providers.dart';
import '../../ui/ui.dart';

/// Mănușa prin Wi-Fi: căutarea în rețea, lista găsită și adresa scrisă de mână.
class WifiPanel extends ConsumerStatefulWidget {
  const WifiPanel({super.key});

  @override
  ConsumerState<WifiPanel> createState() => _WifiPanelState();
}

class _WifiPanelState extends ConsumerState<WifiPanel> {
  final _address = TextEditingController();
  List<WifiGlove>? _found;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _address.text = ref.read(settingsProvider).wifiHost ?? '';
  }

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() => _searching = true);
    final list = await WifiFinder.find();
    if (mounted) {
      setState(() {
        _found = list;
        _searching = false;
      });
    }
  }

  void _use(String host, {String? name}) {
    ref.read(settingsProvider.notifier).update((s) => s.copyWith(wifiHost: host.trim(), wifiName: name ?? s.wifiName ?? 'Mănușa'));
    _address.text = host.trim();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final connection = ref.watch(connectionProvider).value ?? GloveConnection.disconnected;
    final connected = connection == GloveConnection.connected;
    final hasHost = settings.wifiHost != null && settings.wifiHost!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          child: Row(
            children: [
              Icon(
                connected ? Symbols.wifi_rounded : (hasHost ? Symbols.sync_rounded : Symbols.wifi_find_rounded),
                color: connected ? AppColors.connected : AppColors.amber,
                size: 30,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connected
                          ? 'Primesc date prin Wi-Fi'
                          : (hasHost ? 'Mă conectez la ${settings.wifiName ?? 'mănușă'}…' : 'Nicio mănușă aleasă'),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      hasHost ? settings.wifiHost! : 'Caută mănușa în rețea sau scrie adresa ei.',
                      style: TextStyle(fontSize: 15, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        OutlineBigButton(
          icon: Symbols.wifi_find_rounded,
          title: _searching ? 'Caut în rețea…' : 'Caută mănușa în rețea',
          subtitle: 'telefonul și mănușa trebuie să fie în aceeași rețea',
          onPressed: _searching ? null : _search,
        ),
        if (_found != null) ...[
          const SizedBox(height: 12),
          if (_found!.isEmpty)
            Text(
              'Nicio mănușă nu a răspuns. Verifică dacă mănușa e pornită și pusă pe Wi-Fi. În emulator, scrie adresa de mână.',
              style: TextStyle(fontSize: 16, color: AppColors.textMuted),
            )
          else
            for (final g in _found!) ...[
              AppCard(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(g.name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                          Text(g.host, style: TextStyle(fontSize: 15, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 150,
                      child: GradientButton(
                        label: S.connect,
                        height: 52,
                        onPressed: () => _use(g.host, name: g.name),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
        ],
        const SizedBox(height: 16),
        const SectionLabel('Adresa scrisă de mână'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _address,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(hintText: 'ex. 192.168.1.37'),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 120,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 60)),
                onPressed: () {
                  if (!WifiFinder.isValidHost(_address.text)) {
                    showMessage('Adresa nu e bună. Scrie-o ca în exemplu: 192.168.1.37');
                    return;
                  }
                  _use(_address.text);
                },
                child: const Text('Folosește'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Adresa o vezi în monitorul serial al mănușii, pe rândul „Wi-Fi conectat”.',
          style: TextStyle(fontSize: 15, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

/// Cât timp mănușa e pe USB: îi trimite rețeaua Wi-Fi (comanda „W rețea;parolă”), ca s-o poți folosi fără cablu.
class WifiSetupCard extends ConsumerStatefulWidget {
  const WifiSetupCard({super.key});

  @override
  ConsumerState<WifiSetupCard> createState() => _WifiSetupCardState();
}

class _WifiSetupCardState extends ConsumerState<WifiSetupCard> {
  final _ssid = TextEditingController();
  final _password = TextEditingController();
  bool _show = false;

  @override
  void dispose() {
    _ssid.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final ssid = _ssid.text.trim();
    if (ssid.isEmpty || ssid.contains(';')) {
      showMessage('Scrie numele rețelei (fără „;”).');
      return;
    }
    final source = ref.read(gloveSourceProvider);
    final ok = source is UsbGlove && await source.sendLine('W $ssid;${_password.text}');
    if (!mounted) return;
    if (ok) {
      _password.clear();
      FocusScope.of(context).unfocus();
      showMessage('Am trimis rețeaua mănușii. Adresa ei apare în monitorul serial.');
    } else {
      showMessage('Mănușa nu e legată prin USB.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Symbols.wifi_rounded, color: AppColors.accentDark, size: 26),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Pune mănușa pe Wi-Fi', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Mănușa ține minte rețeaua. Data viitoare o folosești fără cablu de date: alege Wi-Fi ca sursă.',
            style: TextStyle(fontSize: 15, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ssid,
            style: const TextStyle(fontSize: 18),
            decoration: const InputDecoration(hintText: 'Numele rețelei'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _password,
            obscureText: !_show,
            style: const TextStyle(fontSize: 18),
            decoration: InputDecoration(
              hintText: 'Parola rețelei',
              suffixIcon: IconButton(
                tooltip: _show ? 'Ascunde parola' : 'Arată parola',
                onPressed: () => setState(() => _show = !_show),
                icon: Icon(_show ? Symbols.visibility_off_rounded : Symbols.visibility_rounded),
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(onPressed: _send, icon: const Icon(Symbols.send_rounded), label: const Text('Trimite mănușii')),
        ],
      ),
    );
  }
}
