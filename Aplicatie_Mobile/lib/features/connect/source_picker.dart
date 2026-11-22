import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/settings_store.dart';
import '../../state/providers.dart';
import '../../ui/ui.dart';

/// Alegerea sursei de date: Demo (fără mănușă), USB (calculator) sau Bluetooth.
class SourcePicker extends ConsumerWidget {
  const SourcePicker({super.key, this.onChanged});

  /// Apelat după schimbare (de ex. ecranul Conectare pornește căutarea Bluetooth).
  final ValueChanged<DataSource>? onChanged;

  static const _icons = {
    DataSource.demo: Symbols.auto_awesome_rounded,
    DataSource.usb: Symbols.usb_rounded,
    DataSource.ble: Symbols.bluetooth_rounded,
    DataSource.wifi: Symbols.wifi_rounded,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = ref.watch(settingsProvider.select((s) => s.source));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(S.dataSource, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        ChoiceTiles<DataSource>(
          options: [for (final s in DataSource.visible) Choice(s, s.label, icon: _icons[s])],
          selected: source,
          onChanged: (v) {
            ref.read(settingsProvider.notifier).update((s) => s.copyWith(source: v));
            onChanged?.call(v);
          },
        ),
        const SizedBox(height: 8),
        Text(S.dataSourceHints[source.index], style: TextStyle(fontSize: 15, color: AppColors.textMuted)),
      ],
    );
  }
}
