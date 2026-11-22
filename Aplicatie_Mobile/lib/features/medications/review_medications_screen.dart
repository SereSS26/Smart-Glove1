import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../app.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/prescription_parser.dart';
import '../../state/reminder_providers.dart';
import '../../ui/ui.dart';
import '../reminders/exact_alarm_prompt.dart';
import '../reminders/medication_form.dart';

/// „Verifică medicamentele”: după scanare sau import, nimic nu se salvează fără acest ecran.
class ReviewMedicationsScreen extends ConsumerStatefulWidget {
  const ReviewMedicationsScreen({super.key, required this.found});

  final List<ParsedMed> found;

  @override
  ConsumerState<ReviewMedicationsScreen> createState() => _ReviewMedicationsScreenState();
}

class _ReviewMedicationsScreenState extends ConsumerState<ReviewMedicationsScreen> {
  late final _meds = [for (var i = 0; i < widget.found.length; i++) widget.found[i].toMedication(color: i)];
  late final _keep = List<bool>.filled(widget.found.length, true);
  bool _saving = false;

  int get _count => [
    for (var i = 0; i < _meds.length; i++)
      if (_keep[i]) i,
  ].length;

  bool get _valid {
    for (var i = 0; i < _meds.length; i++) {
      if (_keep[i] && (_meds[i].name.isEmpty || _meds[i].times.isEmpty)) return false;
    }
    return _count > 0;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final chosen = [
      for (var i = 0; i < _meds.length; i++)
        if (_keep[i]) _meds[i],
    ];
    await ref.read(remindersActionsProvider).saveAll(chosen);
    if (!mounted) return;
    await askExactAlarms(context, ref);
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
    ref.read(patientTabProvider.notifier).go(Tabs.reminders);
    showMessage(chosen.length == 1 ? 'Am adăugat ${chosen.first.title}.' : 'Am adăugat ${chosen.length} medicamente.');
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.found.length;
    final anyUncertain = widget.found.any((m) => m.uncertain.isNotEmpty);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSizes.pagePadding, 16, AppSizes.pagePadding, 32),
          children: [
            BackHeader(title: n == 1 ? 'Am găsit un medicament' : 'Am găsit $n medicamente', subtitle: 'Verifică fiecare rând cu rețeta.'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warningBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.warningBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Symbols.visibility_rounded, color: AppColors.warningFg),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Aplicația poate citi greșit. Verifică întotdeauna cu rețeta.'
                      '${anyUncertain ? '\nSemnul ! arată ce am citit nesigur.' : ''}',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.warningFg, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
            for (var i = 0; i < n; i++) ...[
              const SizedBox(height: 14),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MergeSemantics(
                      child: Row(
                        children: [
                          Checkbox(value: _keep[i], onChanged: (v) => setState(() => _keep[i] = v ?? false)),
                          Expanded(
                            child: Text(
                              _keep[i] ? 'Îl adaug' : 'Nu îl adaug',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: _keep[i] ? AppColors.text : AppColors.textMuted,
                              ),
                            ),
                          ),
                          PillAvatar(color: _meds[i].swatch, size: 36),
                        ],
                      ),
                    ),
                    if (_keep[i]) ...[
                      MedicationFields(
                        initial: _meds[i],
                        uncertain: widget.found[i].uncertain,
                        compact: true,
                        onChanged: (m) => setState(() => _meds[i] = m),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Citit din: „${widget.found[i].source.trim()}”',
                        style: TextStyle(fontSize: 14, color: AppColors.textMuted, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            GradientButton(
              label: _count == 1 ? 'Salvează medicamentul' : 'Salvează $_count medicamente',
              icon: Symbols.check_rounded,
              onPressed: _valid && !_saving ? _save : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Deschide verificarea, sau spune clar că nu s-a găsit nimic.
Future<void> openReview(BuildContext context, String text, {VoidCallback? onNothing}) async {
  final found = parsePrescription(text);
  if (found.isEmpty) {
    if (onNothing != null) {
      onNothing();
    } else {
      showMessage('Nu am găsit niciun medicament în text. Verifică textul sau adaugă manual.');
    }
    return;
  }
  await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ReviewMedicationsScreen(found: found)));
}
