import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/theme.dart';
import '../../data/medications.dart';
import '../../ui/ui.dart';
import '../medications/import_text_screen.dart';
import '../medications/scan_screen.dart';
import 'medication_form.dart';
import 'reminder_edit_screen.dart';

/// Ce se poate adăuga din fila Remindere: rețeta (scanată sau ca text), un medicament, un reminder.
Future<void> showAddSheet(BuildContext context) {
  void go(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (c) {
      void pick(VoidCallback f) {
        Navigator.pop(c);
        f();
      }

      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSizes.pagePadding, 0, AppSizes.pagePadding, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Ce adaugi?', style: Theme.of(c).textTheme.titleLarge),
              const SizedBox(height: 12),
              SettingsGroup(
                children: [
                  NavRow(
                    icon: Symbols.document_scanner_rounded,
                    title: 'Scanează rețeta',
                    subtitle: 'cu camera sau o poză din galerie',
                    onTap: () => pick(() => go(const ScanScreen())),
                  ),
                  NavRow(
                    icon: Symbols.content_paste_rounded,
                    title: 'Importă din notițe',
                    subtitle: 'lipești textul rețetei',
                    onTap: () => pick(() => go(const ImportTextScreen())),
                  ),
                  NavRow(
                    icon: Symbols.medication_rounded,
                    title: 'Adaugă manual',
                    subtitle: 'un medicament, cu orele și stocul',
                    onTap: () => pick(() => go(const MedicationEditScreen())),
                  ),
                  NavRow(
                    icon: Symbols.ecg_heart_rounded,
                    title: 'Reminder de test',
                    subtitle: 'evaluarea zilnică, la ora aleasă',
                    onTap: () => pick(() => go(const ReminderEditScreen(kind: ReminderKind.test))),
                  ),
                  NavRow(
                    icon: Symbols.notifications_rounded,
                    title: 'Alt reminder',
                    subtitle: 'exerciții, plimbare, apă…',
                    onTap: () => pick(() => go(const ReminderEditScreen())),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
