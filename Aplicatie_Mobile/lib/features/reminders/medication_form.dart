import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../app.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/medications.dart';
import '../../state/reminder_providers.dart';
import '../../ui/ui.dart';
import 'exact_alarm_prompt.dart';

/// Cât intră de obicei într-o cutie; `−`/`+` sar între ele.
const _packSizes = [10, 14, 20, 28, 30, 50, 56, 60, 90, 100];

/// Alege o oră (format 24 h).
Future<String?> pickTime(BuildContext context, String initial) async {
  final (h, m) = parseHm(initial);
  final t = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: h, minute: m),
    helpText: 'Alege ora',
    cancelText: 'Renunță',
    confirmText: 'Gata',
    builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!),
  );
  return t == null ? null : hm(t.hour, t.minute);
}

/// Câmpurile unui medicament, fără tastatură acolo unde se poate. Folosit la „Adaugă manual”
/// și pe ecranul de verificare după scanarea rețetei. [uncertain] marchează ce s-a citit nesigur.
class MedicationFields extends StatefulWidget {
  const MedicationFields({super.key, required this.initial, required this.onChanged, this.uncertain = const {}, this.compact = false});

  final Medication initial;
  final ValueChanged<Medication> onChanged;

  /// Câmpurile citite nesigur: 'name', 'dose', 'times', 'stock'.
  final Set<String> uncertain;

  /// Fără culoare, notă și avertisment de stoc (pe ecranul de verificare).
  final bool compact;

  @override
  State<MedicationFields> createState() => _MedicationFieldsState();
}

class _MedicationFieldsState extends State<MedicationFields> {
  late Medication _m = widget.initial;
  late final _name = TextEditingController(text: _m.name);
  late final _strength = TextEditingController(text: _m.strength);
  late final _note = TextEditingController(text: _m.note);

  @override
  void dispose() {
    _name.dispose();
    _strength.dispose();
    _note.dispose();
    super.dispose();
  }

  void _set(Medication m) {
    setState(() => _m = m);
    widget.onChanged(m);
  }

  Widget _flag(String field) => widget.uncertain.contains(field)
      ? Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Tooltip(
            message: 'Citit nesigur: verifică cu rețeta',
            child: Icon(Symbols.error_rounded, color: AppColors.warningFg, size: 22, fill: 1),
          ),
        )
      : const SizedBox.shrink();

  Widget _label(String text, String field, {String? hint}) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(child: FieldLabel(text, hint: hint)),
      Padding(padding: const EdgeInsets.only(bottom: 8), child: _flag(field)),
    ],
  );

  Future<void> _addTime() async {
    final t = await pickTime(context, '12:00');
    if (t != null) _set(_m.copyWith(times: sortTimes([..._m.times, t])));
  }

  @override
  Widget build(BuildContext context) {
    final presetTimes = {for (final p in timePresets) p.$2};
    final custom = _m.times.where((t) => !presetTimes.contains(t));
    final step = _m.form.step;
    final packIdx = _packSizes.indexWhere((s) => s >= _m.packSize);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label('Numele', 'name'),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          style: const TextStyle(fontSize: 18),
          decoration: const InputDecoration(hintText: 'ex. Madopar'),
          onChanged: (v) => _set(_m.copyWith(name: v.trim())),
        ),
        const FieldLabel('Concentrația', hint: 'cum scrie pe cutie'),
        TextField(
          controller: _strength,
          textInputAction: TextInputAction.done,
          style: const TextStyle(fontSize: 18),
          decoration: const InputDecoration(hintText: 'ex. 250 mg'),
          onChanged: (v) => _set(_m.copyWith(strength: v.trim())),
        ),
        const FieldLabel('Forma'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in MedForm.values)
              ToggleChip(
                label: f.label,
                selected: _m.form == f,
                onTap: () => _set(_m.copyWith(form: f, dose: f.step == 1 ? _m.dose.ceilToDouble().clamp(1, 99) : _m.dose)),
              ),
          ],
        ),
        _label('Doza', 'dose', hint: 'cât iei o dată'),
        Row(
          children: [
            StepperField(
              value: Fmt.qty(_m.dose),
              valueWidth: 64,
              minusLabel: 'Doză mai mică',
              plusLabel: 'Doză mai mare',
              onMinus: _m.dose > step ? () => _set(_m.copyWith(dose: _m.dose - step)) : null,
              onPlus: _m.dose < 20 ? () => _set(_m.copyWith(dose: _m.dose + step)) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(_m.dose > 1 ? _m.form.plural : _m.form.label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        _label('Orele', 'times', hint: _m.times.isEmpty ? 'alege cel puțin o oră' : 'de ${_m.times.length} ori pe zi'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (name, t) in timePresets)
              ToggleChip(
                label: '$name $t',
                selected: _m.times.contains(t),
                onTap: () => _set(_m.copyWith(times: _m.times.contains(t) ? (_m.times.toList()..remove(t)) : sortTimes([..._m.times, t]))),
              ),
            for (final t in custom)
              ToggleChip(
                label: t,
                selected: true,
                semanticsLabel: 'Ora $t, apasă ca s-o scoți',
                onTap: () => _set(_m.copyWith(times: _m.times.toList()..remove(t))),
              ),
            ToggleChip(label: 'Altă oră', icon: Symbols.add_rounded, selected: false, onTap: _addTime),
          ],
        ),
        _label('Câte ai acum', 'stock', hint: _m.daysLeft == null ? null : 'ajung pentru ${_days(_m.daysLeft!)}'),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            StepperField(
              value: Fmt.stock(_m.stock),
              valueWidth: 72,
              minusLabel: 'Mai puține',
              plusLabel: 'Mai multe',
              onMinus: _m.stock >= 1 ? () => _set(_m.copyWith(stock: _m.stock - 1)) : null,
              onPlus: () => _set(_m.copyWith(stock: _m.stock + 1)),
            ),
            ToggleChip(
              label: '+ o cutie (${_m.packSize})',
              selected: false,
              onTap: () => _set(_m.copyWith(stock: _m.stock + _m.packSize)),
            ),
          ],
        ),
        const FieldLabel('Câte sunt într-o cutie'),
        StepperField(
          value: '${_m.packSize}',
          valueWidth: 64,
          minusLabel: 'Cutie mai mică',
          plusLabel: 'Cutie mai mare',
          onMinus: _m.packSize > _packSizes.first
              ? () => _set(_m.copyWith(packSize: _packSizes.lastWhere((s) => s < _m.packSize, orElse: () => _packSizes.first)))
              : null,
          onPlus: packIdx >= 0 && _m.packSize < _packSizes.last
              ? () => _set(_m.copyWith(packSize: _packSizes.firstWhere((s) => s > _m.packSize)))
              : null,
        ),
        if (!widget.compact) ...[
          const FieldLabel('Anunță-mă când mai ajunge pentru'),
          Row(
            children: [
              StepperField(
                value: '${_m.warnDays}',
                minusLabel: 'Mai puține zile',
                plusLabel: 'Mai multe zile',
                onMinus: _m.warnDays > 1 ? () => _set(_m.copyWith(warnDays: _m.warnDays - 1)) : null,
                onPlus: _m.warnDays < 14 ? () => _set(_m.copyWith(warnDays: _m.warnDays + 1)) : null,
              ),
              const SizedBox(width: 12),
              const Text('zile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ],
          ),
          const FieldLabel('Culoarea', hint: 'ca să-l recunoști ușor'),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var i = 0; i < medColors.length; i++)
                Semantics(
                  label: 'Culoarea ${i + 1}',
                  selected: _m.color == i,
                  button: true,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _set(_m.copyWith(color: i)),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: medColors[i],
                        shape: BoxShape.circle,
                        border: Border.all(color: _m.color == i ? AppColors.text : Colors.transparent, width: 3),
                      ),
                      child: _m.color == i ? const Icon(Symbols.check_rounded, color: Colors.white) : null,
                    ),
                  ),
                ),
            ],
          ),
          const FieldLabel('Notă', hint: 'opțional, ex. „după masă”'),
          TextField(
            controller: _note,
            style: const TextStyle(fontSize: 18),
            decoration: const InputDecoration(hintText: 'Notă'),
            onChanged: (v) => _set(_m.copyWith(note: v.trim())),
          ),
        ],
      ],
    );
  }
}

String _days(double d) {
  final n = d.floor();
  return n == 1 ? 'o zi' : '$n zile';
}

/// Adaugă sau editează un medicament.
class MedicationEditScreen extends ConsumerStatefulWidget {
  const MedicationEditScreen({super.key, this.medication});

  final Medication? medication;

  @override
  ConsumerState<MedicationEditScreen> createState() => _MedicationEditScreenState();
}

class _MedicationEditScreenState extends ConsumerState<MedicationEditScreen> {
  late Medication _m = widget.medication ?? Medication(name: '', createdAt: DateTime.now());
  bool _saving = false;

  bool get _valid => _m.name.isNotEmpty && _m.times.isNotEmpty;

  Future<void> _save() async {
    setState(() => _saving = true);
    await ref.read(remindersActionsProvider).save(_m);
    if (!mounted) return;
    await askExactAlarms(context, ref);
    if (!mounted) return;
    Navigator.of(context).pop();
    showMessage(widget.medication == null ? '${_m.title} a fost adăugat.' : 'Am salvat ${_m.title}.');
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Ștergi ${_m.title}?'),
        content: const Text('Dispar și reminderele lui. Dozele deja bifate se șterg și ele.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Renunță')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Șterge')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(remindersActionsProvider).delete(_m);
    if (!mounted) return;
    Navigator.of(context).pop();
    showMessage('${_m.title} a fost șters.');
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.medication != null;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSizes.pagePadding, 16, AppSizes.pagePadding, 32),
          children: [
            BackHeader(title: editing ? 'Editează medicamentul' : 'Medicament nou'),
            const SizedBox(height: 4),
            MedicationFields(initial: _m, onChanged: (m) => setState(() => _m = m)),
            const SizedBox(height: 24),
            GradientButton(label: 'Salvează', icon: Symbols.check_rounded, onPressed: _valid && !_saving ? _save : null),
            if (!_valid)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _m.name.isEmpty ? 'Scrie numele medicamentului.' : 'Alege cel puțin o oră.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: AppColors.textMuted),
                ),
              ),
            if (editing) ...[
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: _delete,
                icon: Icon(Symbols.delete_rounded, color: AppColors.bad),
                label: Text(
                  'Șterge medicamentul',
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
