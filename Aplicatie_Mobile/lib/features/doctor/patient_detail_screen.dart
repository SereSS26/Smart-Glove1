import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../app.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/clinic_repository.dart';
import '../../data/medications.dart';
import '../../state/clinic_providers.dart';
import '../../ui/ui.dart';
import '../history/charts.dart';
import '../history/history_screen.dart';
import 'doctor_export.dart';
import 'doctor_prefs.dart';

enum _Tab { overview, sessions, meds }

/// Detaliul unui pacient: Prezentare · Sesiuni · Medicație, pe 7 / 30 / 90 de zile, cu export.
class PatientDetailScreen extends ConsumerStatefulWidget {
  const PatientDetailScreen({super.key, required this.patient, this.embedded = false});

  final ClinicPatient patient;

  /// În coloana din dreapta, pe tabletă: fără ecran propriu și fără butonul înapoi.
  final bool embedded;

  @override
  ConsumerState<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends ConsumerState<PatientDetailScreen> {
  _Tab _tab = _Tab.overview;
  late int _days = ref.read(doctorPrefsProvider).days;

  Future<void> _export() async {
    final pdf = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSizes.pagePadding, 0, AppSizes.pagePadding, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Exportă · ultimele $_days zile', style: Theme.of(c).textTheme.titleLarge),
              const SizedBox(height: 12),
              SettingsGroup(
                children: [
                  NavRow(
                    icon: Symbols.picture_as_pdf_rounded,
                    title: 'Raport PDF',
                    subtitle: 'cifrele, graficul cu pragul, sesiunile, medicația',
                    onTap: () => Navigator.pop(c, true),
                  ),
                  NavRow(
                    icon: Symbols.table_rows_rounded,
                    title: 'Date CSV',
                    subtitle: 'un rând pe zi, pentru Excel',
                    onTap: () => Navigator.pop(c, false),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (pdf == null) return;
    try {
      await exportPatients(ref, [widget.patient], ExportOptions(days: _days, pdf: pdf));
    } catch (e) {
      showMessage('Nu am putut face exportul: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.patient;
    final async = ref.watch(patientDetailProvider((p.id, _days)));
    final list = ListView(
      padding: const EdgeInsets.fromLTRB(AppSizes.pagePadding, 16, AppSizes.pagePadding, 32),
      children: [
        BackHeader(
          showBack: !widget.embedded,
          title: p.name,
          subtitle: p.local ? '${p.details} · date de pe acest telefon' : p.details,
          trailing: IconButton.filledTonal(
            tooltip: 'Exportă',
            onPressed: _export,
            style: IconButton.styleFrom(
              minimumSize: const Size(48, 48),
              backgroundColor: AppColors.accentSoft,
              foregroundColor: AppColors.accentDark,
            ),
            icon: const Icon(Symbols.ios_share_rounded),
          ),
        ),
        const SizedBox(height: 12),
        AppSegmented<_Tab>(
          options: const [Choice(_Tab.overview, 'Prezentare'), Choice(_Tab.sessions, 'Sesiuni'), Choice(_Tab.meds, 'Medicație')],
          selected: _tab,
          onChanged: (t) => setState(() => _tab = t),
        ),
        const SizedBox(height: 10),
        AppSegmented<int>(
          options: const [Choice(7, '7 zile'), Choice(30, '30 zile'), Choice(90, '90 zile')],
          selected: _days,
          height: 46,
          onChanged: (d) => setState(() => _days = d),
        ),
        const SizedBox(height: 14),
        ...async.when(
          data: (d) => switch (_tab) {
            _Tab.overview => _overview(d),
            _Tab.sessions => _sessions(d),
            _Tab.meds => _meds(d),
          },
          loading: () => [
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
          error: (e, _) => [AppCard(child: Text('Nu am putut citi datele: $e'))],
        ),
      ],
    );
    if (widget.embedded) return list;
    return Scaffold(body: SafeArea(child: list));
  }

  List<Widget> _overview(PatientDetail d) {
    final s = d.stats;
    final threshold = d.record.patient.threshold;
    if (s.mean == null) {
      return [
        const AppCard(
          child: EmptyState(icon: Symbols.monitoring_rounded, text: 'Nicio înregistrare în această perioadă.'),
        ),
      ];
    }
    return [
      MetricGrid(
        children: [
          MetricTile(
            label: 'Media indicelui',
            value: '${s.mean!.round()}',
            badge: s.deltaPercent == null ? null : DeltaBadge(percent: s.deltaPercent!, showWord: false),
            sub: s.deltaPercent == null ? 'fără comparație' : 'față de cele $_days zile dinainte',
          ),
          MetricTile(label: 'Peste prag', value: '${s.overThreshold!.round()} %', sub: 'din timp · prag $threshold'),
          MetricTile(label: 'Aderență', value: d.adherence == null ? '—' : '${d.adherence} %', sub: 'doze luate la timp'),
          MetricTile(label: 'Sesiuni', value: '${s.sessions}', sub: '${s.testDays} zile cu evaluare'),
        ],
      ),
      const SizedBox(height: 12),
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _days == 90 ? 'Indicele pe săptămâni' : 'Indicele pe zile',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            IndexBarChart(
              bars: [for (final b in s.bars) BarDatum(b.label, b.value, highlight: b.highlight)],
              threshold: threshold,
              semanticsLabel: 'Indicele de tremor, ultimele $_days zile',
            ),
          ],
        ),
      ),
      if (s.cells.length >= 7) ...[
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Ultimele ${s.cells.length} zile', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              MonthHeatmap(cells: s.cells, leadingBlanks: s.leadingBlanks),
            ],
          ),
        ),
      ],
      if (d.record.tapping.length >= 2) ...[
        const SizedBox(height: 12),
        TappingCard(rates: d.record.tapping.length > 12 ? d.record.tapping.sublist(d.record.tapping.length - 12) : d.record.tapping),
      ],
      if (d.insights.isNotEmpty) ...[
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('Perspective'),
              const SizedBox(height: 6),
              for (final i in d.insights)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Symbols.lightbulb_rounded, size: 20, color: AppColors.accentDark),
                      const SizedBox(width: 8),
                      Expanded(child: Text(i, style: const TextStyle(fontSize: 16, height: 1.35))),
                    ],
                  ),
                ),
              Text('Observații din date, nu diagnostic.', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
            ],
          ),
        ),
      ],
    ];
  }

  List<Widget> _sessions(PatientDetail d) {
    final list = d.record.sessions.where((s) => d.stats.range.contains(s.startedAt)).toList();
    if (list.isEmpty) {
      return [
        const AppCard(
          child: EmptyState(icon: Symbols.history_rounded, text: 'Nicio sesiune în această perioadă.'),
        ),
      ];
    }
    return [
      for (final s in list.take(60)) ...[SessionTile(session: s, readOnly: !d.record.patient.local), const SizedBox(height: 8)],
      if (list.length > 60)
        Text(
          '… și încă ${list.length - 60}. Exportul CSV le cuprinde pe toate.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textMuted),
        ),
    ];
  }

  List<Widget> _meds(PatientDetail d) {
    final meds = d.record.meds;
    if (meds.isEmpty) {
      return [
        const AppCard(
          child: EmptyState(icon: Symbols.medication_rounded, text: 'Pacientul nu are medicamente înregistrate.'),
        ),
      ];
    }
    final now = DateTime.now();
    final today = dayOf(now);
    final taken = {
      for (final i in d.record.intakes)
        if (i.status == IntakeStatus.taken) '${i.medId}@${i.scheduledAt.millisecondsSinceEpoch}',
    };
    return [
      AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(child: SectionLabel('Aderența, ultimele 14 zile')),
                if (d.adherence != null) Text('${d.adherence} %', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 10),
            // O căsuță pe zi: verde = toate dozele, chihlimbar = o parte, roșu = niciuna.
            Row(
              children: [
                for (var k = 13; k >= 0; k--)
                  Expanded(
                    child: Builder(
                      builder: (_) {
                        final day = DateTime(today.year, today.month, today.day - k);
                        var due = 0, ok = 0;
                        for (final m in meds) {
                          for (final t in m.times) {
                            final at = atTime(day, t);
                            if (at.isAfter(now)) continue;
                            due++;
                            if (taken.contains('${m.id}@${at.millisecondsSinceEpoch}')) ok++;
                          }
                        }
                        final color = due == 0
                            ? AppColors.divider
                            : (ok == due ? AppColors.ok : (ok == 0 ? AppColors.bad : AppColors.modFg));
                        return Semantics(
                          label: '${Fmt.weekdayDate(day)}: $ok din $due doze',
                          excludeSemantics: true,
                          child: Container(
                            height: 28,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: due == 0 ? 1 : 0.85),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('acum 2 săpt.', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                Text('azi', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      for (final m in meds) ...[
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  PillAvatar(color: m.swatch, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                        Text('${m.doseShort} · ${m.times.join(', ')}', style: TextStyle(fontSize: 15, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              StockBar(fraction: m.stockFraction, low: m.lowStock),
              const SizedBox(height: 4),
              Text(
                'stoc ${Fmt.stock(m.stock)} buc.${m.daysLeft == null ? '' : ' · ajunge ${m.daysLeft!.floor()} zile'}',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: m.lowStock ? AppColors.bad : AppColors.textMuted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
    ];
  }
}
