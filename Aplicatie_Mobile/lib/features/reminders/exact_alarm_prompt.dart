import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../state/providers.dart';
import '../../state/reminder_providers.dart';

/// La primul reminder: dacă telefonul nu lasă aplicația să sune la minut, explică de ce e nevoie
/// de „Alarme și mementouri” și deschide setarea. Se întreabă o singură dată.
Future<void> askExactAlarms(BuildContext context, WidgetRef ref) async {
  final notes = ref.read(notificationsProvider);
  final prefs = ref.read(prefsProvider);
  await notes.requestPermission();
  if (prefs.getBool('rem.exactAsked') == true || await notes.canScheduleExact()) return;
  await prefs.setBool('rem.exactAsked', true);
  if (!context.mounted) return;
  final go = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      icon: const Icon(Symbols.alarm_rounded, size: 36),
      title: const Text('Remindere la ora exactă'),
      content: const Text(
        'Ca reminderul pentru medicament să sune exact la ora aleasă, telefonul cere permisiunea „Alarme și mementouri”.\n\n'
        'Fără ea, notificarea poate întârzia câteva minute.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Mai târziu')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Deschide setarea')),
      ],
    ),
  );
  if (go != true) return;
  await notes.requestExact();
  await ref.read(remindersActionsProvider).reschedule();
}
