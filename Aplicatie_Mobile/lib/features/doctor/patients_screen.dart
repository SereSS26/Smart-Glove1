import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/clinic_repository.dart';
import '../../state/clinic_providers.dart';
import '../../state/providers.dart';
import '../../ui/ui.dart';
import '../settings/account_widgets.dart';
import 'patient_detail_screen.dart';

String greeting(DateTime now) => now.hour < 11 ? 'Bună dimineața,' : (now.hour < 18 ? 'Bună ziua,' : 'Bună seara,');

/// Lista pacienților medicului: cei care necesită atenție primii, fiecare cu motivul.
class PatientsScreen extends ConsumerStatefulWidget {
  const PatientsScreen({super.key});

  @override
  ConsumerState<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends ConsumerState<PatientsScreen> {
  String _query = '';
  ClinicPatient? _selected;

  /// Pe tabletă (lățime ≥ 840): lista în stânga, detaliul pacientului ales în dreapta.
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        if (c.maxWidth < 840) return _list(context, wide: false);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(width: 400, child: _list(context, wide: true)),
            VerticalDivider(width: 1, color: AppColors.divider),
            Expanded(
              child: _selected == null
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: EmptyState(icon: Symbols.person_search_rounded, text: 'Alege un pacient din listă ca să-i vezi graficele.'),
                      ),
                    )
                  : PatientDetailScreen(key: ValueKey(_selected!.id), patient: _selected!, embedded: true),
            ),
          ],
        );
      },
    );
  }

  Widget _card(PatientSummary s, bool wide) => PatientCard(
    summary: s,
    selected: wide && _selected?.id == s.patient.id,
    onOpen: wide ? () => setState(() => _selected = s.patient) : null,
  );

  Widget _list(BuildContext context, {required bool wide}) {
    final user = ref.watch(authProvider);
    final async = ref.watch(patientSummariesProvider);
    final all = async.value ?? const <PatientSummary>[];
    final q = _query.trim().toLowerCase();
    final shown = q.isEmpty ? all : all.where((s) => s.patient.name.toLowerCase().contains(q)).toList();
    final attention = shown.where((s) => s.needsAttention).toList();
    final others = shown.where((s) => !s.needsAttention).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSizes.pagePadding, 14, AppSizes.pagePadding, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(greeting(DateTime.now()), style: TextStyle(fontSize: 16, color: AppColors.textMuted)),
                  Text(user?.name ?? '', style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            if (user != null) Avatar(initials: user.initials, size: 48),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _CountTile(icon: Symbols.group_rounded, value: '${all.length}', label: all.length == 1 ? 'pacient' : 'pacienți'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _CountTile(
                icon: Symbols.priority_high_rounded,
                value: '${all.where((s) => s.needsAttention).length}',
                label: 'de urmărit',
                warn: all.any((s) => s.needsAttention),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          onChanged: (v) => setState(() => _query = v),
          style: const TextStyle(fontSize: 17),
          decoration: const InputDecoration(hintText: 'Caută pacient…', prefixIcon: Icon(Symbols.search_rounded)),
        ),
        if (async.isLoading && all.isEmpty)
          const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (async.hasError) AppCard(child: Text('Nu am putut citi pacienții: ${async.error}')),
        if (attention.isNotEmpty) ...[
          const Padding(padding: EdgeInsets.fromLTRB(4, 20, 4, 8), child: SectionLabel('Necesită atenție')),
          for (final s in attention) ...[_card(s, wide), const SizedBox(height: 10)],
        ],
        if (others.isNotEmpty) ...[
          Padding(padding: const EdgeInsets.fromLTRB(4, 14, 4, 8), child: SectionLabel(attention.isEmpty ? 'Pacienți' : 'Ceilalți')),
          for (final s in others) ...[_card(s, wide), const SizedBox(height: 10)],
        ],
        if (!async.isLoading && shown.isEmpty && q.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Niciun pacient nu se potrivește cu „$_query”.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 16),
            ),
          ),
      ],
    );
  }
}

class _CountTile extends StatelessWidget {
  const _CountTile({required this.icon, required this.value, required this.label, this.warn = false});

  final IconData icon;
  final String value;
  final String label;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: warn ? AppColors.warningBg : null,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: warn ? AppColors.warningFg : AppColors.accentDark, fill: 1),
          const SizedBox(width: 10),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, fontFeatures: tabular),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: warn ? AppColors.warningFg : AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

/// Cardul unui pacient: inițiale, mini-grafic pe 14 zile, indicele pe 7 zile, tendința și motivul pentru care e de urmărit.
class PatientCard extends StatelessWidget {
  const PatientCard({super.key, required this.summary, this.onOpen, this.selected = false});

  final PatientSummary summary;

  /// Ce face apăsarea (pe tabletă: alege pacientul); implicit deschide detaliul pe tot ecranul.
  final VoidCallback? onOpen;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final p = s.patient;
    final values = [for (final v in s.daily) ?v];
    final sev = s.mean7 == null ? null : Severity.fromIndex(s.mean7!.round());
    final subtitle = s.reasons.isNotEmpty
        ? s.reasons.join(' · ')
        : (p.local ? 'date de pe acest telefon' : (s.adherence7 == null ? 'stabil' : 'stabil · aderență ${s.adherence7} %'));
    return AppCard(
      padding: EdgeInsets.zero,
      color: selected ? AppColors.accentSoft : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSizes.radius),
        onTap: onOpen ?? () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PatientDetailScreen(patient: p))),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Avatar(
                    initials: p.initials,
                    size: 46,
                    background: s.needsAttention ? AppColors.warningBg : null,
                    foreground: s.needsAttention ? AppColors.warningFg : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${p.name}, ${p.age} ani', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                        Text(p.diagnosis, style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  Icon(Symbols.chevron_right_rounded, color: AppColors.textMuted),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: values.length >= 2
                        ? TrendChart(values: values, threshold: p.threshold, height: 44, semanticsLabel: 'Tendința pe 14 zile')
                        : Text('fără date recente', style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
                  ),
                  const SizedBox(width: 12),
                  if (s.mean7 != null) ...[
                    Text(
                      '${s.mean7!.round()}',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, fontFeatures: tabular),
                    ),
                    const SizedBox(width: 6),
                    SeverityChip(sev!),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (s.needsAttention) ...[
                    Icon(Symbols.error_rounded, size: 18, color: AppColors.warningFg, fill: 1),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: s.needsAttention ? FontWeight.w700 : FontWeight.w400,
                        color: s.needsAttention ? AppColors.warningFg : AppColors.textMuted,
                      ),
                    ),
                  ),
                  if (s.delta7 != null) DeltaBadge(percent: s.delta7!, showWord: false),
                ],
              ),
              if (s.lastData != null && !s.needsAttention)
                Text('ultimele date: ${Fmt.dayAndTime(s.lastData!)}', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}
