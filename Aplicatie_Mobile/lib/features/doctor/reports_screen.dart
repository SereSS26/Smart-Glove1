import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../app.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/clinic_repository.dart';
import '../../state/clinic_providers.dart';
import '../../ui/ui.dart';
import '../settings/account_widgets.dart';
import 'doctor_export.dart';
import 'doctor_prefs.dart';

final _clinicPatientsProvider = FutureProvider.autoDispose<List<ClinicPatient>>((ref) => ref.watch(clinicProvider).patients());

/// Rapoarte: alegi pacienții, perioada, formatul și ce conține, apoi le trimiți (un fișier pe pacient).
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  final _chosen = <String>{};
  late int _days = ref.read(doctorPrefsProvider).days;
  late bool _pdf = ref.read(doctorPrefsProvider).pdf;
  bool _charts = true;
  bool _sessions = true;
  bool _meds = true;
  bool _busy = false;

  Future<void> _go(List<ClinicPatient> all) async {
    setState(() => _busy = true);
    try {
      final picked = all.where((p) => _chosen.contains(p.id)).toList();
      final n = await exportPatients(ref, picked, ExportOptions(days: _days, pdf: _pdf, charts: _charts, sessions: _sessions, meds: _meds));
      showMessage(n == 1 ? 'Raportul e gata de trimis.' : '$n rapoarte gata de trimis.');
    } catch (e) {
      showMessage('Nu am putut face rapoartele: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final patients = ref.watch(_clinicPatientsProvider).value ?? const <ClinicPatient>[];
    final allChosen = patients.isNotEmpty && _chosen.length == patients.length;
    Widget label(String t) => Padding(padding: const EdgeInsets.fromLTRB(4, 18, 4, 8), child: SectionLabel(t));
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSizes.pagePadding, 14, AppSizes.pagePadding, 24),
      children: [
        Text(S.tabReports, style: Theme.of(context).textTheme.headlineMedium),
        Text(
          'Un fișier pentru fiecare pacient, trimis din telefon (e-mail, WhatsApp, Drive).',
          style: TextStyle(fontSize: 15, color: AppColors.textMuted),
        ),
        label('Pacienții'),
        SettingsGroup(
          children: [
            _CheckRow(
              title: 'Toți pacienții',
              value: allChosen,
              onChanged: (v) => setState(() => v ? _chosen.addAll(patients.map((p) => p.id)) : _chosen.clear()),
            ),
            for (final p in patients)
              _CheckRow(
                title: p.name,
                subtitle: p.local ? '${p.details} · de pe acest telefon' : p.details,
                leading: Avatar(initials: p.initials, size: 36),
                value: _chosen.contains(p.id),
                onChanged: (v) => setState(() => v ? _chosen.add(p.id) : _chosen.remove(p.id)),
              ),
          ],
        ),
        label('Perioada'),
        AppSegmented<int>(
          options: const [Choice(7, '7 zile'), Choice(30, '30 zile'), Choice(90, '90 zile')],
          selected: _days,
          onChanged: (d) => setState(() => _days = d),
        ),
        label('Formatul'),
        ChoiceTiles<bool>(
          options: const [
            Choice(true, 'PDF', icon: Symbols.picture_as_pdf_rounded),
            Choice(false, 'CSV', icon: Symbols.table_rows_rounded),
          ],
          selected: _pdf,
          onChanged: (v) => setState(() => _pdf = v),
        ),
        if (_pdf) ...[
          label('Ce conține'),
          SettingsGroup(
            children: [
              SwitchRow(title: 'Grafice', subtitle: 'indicele cu pragul', value: _charts, onChanged: (v) => setState(() => _charts = v)),
              SwitchRow(title: 'Sesiuni și teste', value: _sessions, onChanged: (v) => setState(() => _sessions = v)),
              SwitchRow(title: 'Medicație', value: _meds, onChanged: (v) => setState(() => _meds = v)),
            ],
          ),
        ],
        const SizedBox(height: 22),
        GradientButton(
          label: _chosen.isEmpty ? 'Alege cel puțin un pacient' : 'Generează și trimite (${_chosen.length})',
          icon: Symbols.send_rounded,
          onPressed: _chosen.isEmpty || _busy ? null : () => _go(patients),
        ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.only(top: 12),
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.title, this.subtitle, this.leading, required this.value, required this.onChanged});

  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: InkWell(
        onTap: () => onChanged(!value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
            child: Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 12)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      if (subtitle != null) Text(subtitle!, style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                Checkbox(value: value, onChanged: (v) => onChanged(v ?? false)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
