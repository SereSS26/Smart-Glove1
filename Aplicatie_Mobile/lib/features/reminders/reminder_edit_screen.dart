import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../app.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/medications.dart';
import '../../state/reminder_providers.dart';
import '../../ui/ui.dart';
import 'exact_alarm_prompt.dart';
import 'medication_form.dart';

const testReminderTitle = 'Evaluare completă';

/// Adaugă sau editează un reminder de test ori unul simplu.
class ReminderEditScreen extends ConsumerStatefulWidget {
  const ReminderEditScreen({super.key, this.reminder, this.kind = ReminderKind.other});

  final ReminderItem? reminder;
  final ReminderKind kind;

  @override
  ConsumerState<ReminderEditScreen> createState() => _ReminderEditScreenState();
}

class _ReminderEditScreenState extends ConsumerState<ReminderEditScreen> {
  late ReminderItem _r =
      widget.reminder ??
      ReminderItem(
        kind: widget.kind,
        title: widget.kind == ReminderKind.test ? testReminderTitle : '',
        time: widget.kind == ReminderKind.test ? '09:00' : '18:00',
      );
  late final _title = TextEditingController(text: _r.title);

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  bool get _test => _r.kind == ReminderKind.test;
  bool get _valid => _r.title.trim().isNotEmpty && _r.days.isNotEmpty;

  Future<void> _save() async {
    await ref.read(remindersActionsProvider).saveReminder(_r.copyWith(title: _r.title.trim()));
    if (!mounted) return;
    await askExactAlarms(context, ref);
    if (!mounted) return;
    Navigator.of(context).pop();
    showMessage('Reminderul „${_r.title.trim()}” sună la ${_r.time}, ${_r.daysLabel}.');
  }

  Future<void> _delete() async {
    await ref.read(remindersActionsProvider).deleteReminder(_r);
    if (!mounted) return;
    Navigator.of(context).pop();
    showMessage('Reminderul a fost șters.');
  }

  @override
  Widget build(BuildContext context) {
    const letters = ['L', 'Ma', 'Mi', 'J', 'V', 'S', 'D'];
    const names = ['luni', 'marți', 'miercuri', 'joi', 'vineri', 'sâmbătă', 'duminică'];
    final editing = widget.reminder != null;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSizes.pagePadding, 16, AppSizes.pagePadding, 32),
          children: [
            BackHeader(
              title: _test ? 'Reminder de test' : (editing ? 'Editează reminderul' : 'Reminder nou'),
              subtitle: _test ? 'Te anunță când e timpul pentru evaluarea zilnică (cam 3 minute).' : null,
            ),
            if (!_test) ...[
              const FieldLabel('Ce îți amintim'),
              TextField(
                controller: _title,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 18),
                decoration: const InputDecoration(hintText: 'ex. Exerciții pentru mâini'),
                onChanged: (v) => setState(() => _r = _r.copyWith(title: v)),
              ),
            ],
            const FieldLabel('Ora'),
            OutlineBigButton(
              icon: Symbols.schedule_rounded,
              title: _r.time,
              subtitle: 'Apasă ca s-o schimbi',
              onPressed: () async {
                final t = await pickTime(context, _r.time);
                if (t != null) setState(() => _r = _r.copyWith(time: t));
              },
            ),
            FieldLabel('Zilele', hint: _r.days.isEmpty ? 'alege cel puțin o zi' : _r.daysLabel),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var d = 1; d <= 7; d++)
                  ToggleChip(
                    label: letters[d - 1],
                    semanticsLabel: names[d - 1],
                    selected: _r.days.contains(d),
                    onTap: () => setState(
                      () => _r = _r.copyWith(days: _r.days.contains(d) ? (_r.days.toList()..remove(d)) : ([..._r.days, d]..sort())),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 28),
            GradientButton(label: 'Salvează', icon: Symbols.check_rounded, onPressed: _valid ? _save : null),
            if (editing) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _delete,
                icon: Icon(Symbols.delete_rounded, color: AppColors.bad),
                label: Text(
                  'Șterge reminderul',
                  style: TextStyle(color: AppColors.bad, fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
