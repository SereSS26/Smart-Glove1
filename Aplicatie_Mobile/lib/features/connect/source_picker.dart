import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../data/settings_store.dart';
import '../../state/providers.dart';

/// Alegerea sursei de date: simulată, prin USB (calculator) sau prin Bluetooth.
class SourcePicker extends ConsumerWidget {
  const SourcePicker({super.key, this.onChanged});

  /// Apelat după schimbare (de ex. ecranul Conectare pornește căutarea Bluetooth).
  final ValueChanged<DataSource>? onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = ref.watch(settingsProvider.select((s) => s.source));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(S.dataSource, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        SegmentedButton<DataSource>(
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(
            minimumSize: const Size(0, 56),
            textStyle: const TextStyle(fontFamily: 'Atkinson', fontSize: 16, fontWeight: FontWeight.w700),
            selectedBackgroundColor: AppColors.accentSoft,
            selectedForegroundColor: AppColors.accentDark,
          ),
          segments: [for (final s in DataSource.values) ButtonSegment(value: s, label: Text(s.label))],
          selected: {source},
          onSelectionChanged: (v) {
            ref.read(settingsProvider.notifier).update((s) => s.copyWith(source: v.first));
            onChanged?.call(v.first);
          },
        ),
        const SizedBox(height: 8),
        Text(S.dataSourceHints[source.index], style: TextStyle(fontSize: 16, color: AppColors.textMuted)),
      ],
    );
  }
}
