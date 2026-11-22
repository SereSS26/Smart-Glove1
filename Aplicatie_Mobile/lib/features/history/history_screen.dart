import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../app.dart';
import '../../core/format.dart';
import '../../core/strings.dart';
import '../../core/tests.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/db/models.dart';
import '../../services/history_stats.dart';
import '../../services/report_service.dart';
import '../../state/providers.dart';
import '../../state/reminder_providers.dart';
import '../../data/medications.dart';
import '../../ui/ui.dart';
import 'charts.dart';
import 'session_detail_screen.dart';

/// Tot ce arată Istoricul pentru o perioadă.
class HistoryData {
  const HistoryData({required this.stats, required this.sessions, required this.tapping, required this.insights, this.adherence});
  final PeriodStats stats;
  final List<SessionRecord> sessions;

  /// Rezultatele tapping-ului cu mănușa, cele mai vechi primele (ultimele 8).
  final List<double> tapping;
  final List<String> insights;
  final int? adherence;
}

/// Dozele unei perioade: orele cu doze luate (semne pe grafic), aderența și efectul după doză.
typedef DoseInfo = ({Set<int> doseHours, int? adherence, String? insight});
final doseInfoProvider = FutureProvider.autoDispose.family<DoseInfo, (DateTime, DateTime)>((ref, range) async {
  ref.watch(medsVersionProvider);
  final repo = ref.watch(medicationRepositoryProvider);
  final db = ref.watch(databaseProvider);
  final demo = ref.watch(settingsProvider.select((s) => s.demoMode));
  final (from, to) = range;
  final now = DateTime.now();
  final meds = await repo.medications();
  if (meds.isEmpty) return (doseHours: <int>{}, adherence: null, insight: null);
  final intakes = await repo.intakesBetween(from, to);
  final monthAgo = now.subtract(const Duration(days: 30));
  final recent = await repo.intakesBetween(monthAgo, now);
  final samples = await db.samplesBetween(monthAgo, now, simulated: demo);
  return (
    doseHours: {
      for (final i in intakes)
        if (i.status == IntakeStatus.taken) (i.at ?? i.scheduledAt).hour,
    },
    adherence: adherence(meds: meds, intakes: intakes, from: from, to: to, now: now),
    insight: afterDoseInsight(samples, recent),
  );
});

final historyDataProvider = FutureProvider.autoDispose.family<HistoryData, (Period, int)>((ref, key) async {
  final (period, offset) = key;
  final db = ref.watch(databaseProvider);
  final demo = ref.watch(settingsProvider.select((s) => s.demoMode));
  final threshold = ref.watch(settingsProvider.select((s) => s.alertThreshold));
  final sessions = await ref.watch(historyProvider.future);
  final now = DateTime.now();
  final range = rangeFor(period, offset, now);
  final prev = rangeFor(period, offset + 1, now);
  final samples = await db.samplesBetween(range.start, range.end, simulated: demo);
  final previous = await db.samplesBetween(prev.start, prev.end, simulated: demo);
  final dose = await ref.watch(doseInfoProvider((range.start, range.end)).future);
  final stats = computeStats(
    period: period,
    range: range,
    samples: samples,
    previous: previous,
    sessions: sessions,
    threshold: threshold,
    now: now,
    doseHours: dose.doseHours,
  );
  final taps = (await db.resultsOf(TestKind.tappingGlove.id, simulated: demo, limit: 8)).map((r) => r.value).toList().reversed.toList();
  final month = await db.samplesBetween(now.subtract(const Duration(days: 30)), now, simulated: demo);
  return HistoryData(
    stats: stats,
    sessions: sessions.where((s) => range.contains(s.startedAt)).toList(),
    tapping: taps,
    insights: [?morningEveningInsight(month), ?dose.insight],
    adherence: dose.adherence,
  );
});

enum _Filter { all, tests, free }

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  Period _period = Period.week;
  int _offset = 0;
  _Filter _filter = _Filter.all;

  Future<void> _share(HistoryData d) async {
    final user = ref.read(authProvider);
    final meds = await ref.read(medicationRepositoryProvider).medications();
    try {
      await ReportService.share([
        PeriodReport(
          patient: user?.name ?? 'Pacient',
          details: user?.details ?? '',
          stats: d.stats,
          sessions: d.sessions,
          tappingRate: d.tapping.isEmpty ? null : d.tapping.last,
          adherence: d.adherence,
          medications: [for (final m in meds) '${m.title} · ${m.doseShort} · ${m.times.join(', ')}'],
        ),
      ], threshold: ref.read(settingsProvider).alertThreshold);
    } catch (e) {
      showMessage('Nu am putut face raportul: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(historyDataProvider((_period, _offset)));
    final threshold = ref.watch(settingsProvider.select((s) => s.alertThreshold));
    final demo = ref.watch(settingsProvider.select((s) => s.demoMode));
    final range = rangeFor(_period, _offset, DateTime.now());

    return RefreshIndicator(
      onRefresh: () => ref.refresh(historyProvider.future),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSizes.pagePadding, 14, AppSizes.pagePadding, 24),
        children: [
          Row(
            children: [
              Expanded(child: Text(S.historyTitle, style: Theme.of(context).textTheme.headlineMedium)),
              IconButton.outlined(
                tooltip: 'Trimite raportul perioadei',
                constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
                style: IconButton.styleFrom(
                  side: BorderSide(color: AppColors.border),
                  foregroundColor: AppColors.accentDark,
                ),
                onPressed: data.value == null ? null : () => _share(data.value!),
                icon: const Icon(Symbols.download_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppSegmented<Period>(
            options: const [Choice(Period.day, S.day), Choice(Period.week, S.week), Choice(Period.month, 'Lună')],
            selected: _period,
            onChanged: (v) => setState(() {
              _period = v;
              _offset = 0;
            }),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _NavButton(icon: Symbols.chevron_left_rounded, label: 'Perioada anterioară', onTap: () => setState(() => _offset++)),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      range.label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    if (_offset > 0)
                      TextButton(
                        style: TextButton.styleFrom(minimumSize: const Size(48, 36), padding: EdgeInsets.zero),
                        onPressed: () => setState(() => _offset = 0),
                        child: const Text('Înapoi la azi'),
                      ),
                  ],
                ),
              ),
              _NavButton(
                icon: Symbols.chevron_right_rounded,
                label: 'Perioada următoare',
                onTap: _offset == 0 ? null : () => setState(() => _offset--),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (demo) ...[const SimulatedBanner('Sesiuni simulate · mod demonstrativ'), const SizedBox(height: 12)],
          data.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('Nu am putut citi istoricul: $e'),
            data: (d) => _content(d, threshold, demo),
          ),
        ],
      ),
    );
  }

  Widget _content(HistoryData d, int threshold, bool demo) {
    final s = d.stats;
    final shown = d.sessions.where(
      (x) => switch (_filter) {
        _Filter.all => true,
        _Filter.tests => x.kind != SessionKind.free,
        _Filter.free => x.kind == SessionKind.free,
      },
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MetricGrid(
          children: [
            MetricTile(
              label: 'Media indicelui',
              value: s.mean == null ? '—' : '${s.mean!.round()}',
              badge: s.deltaPercent == null ? null : DeltaBadge(percent: s.deltaPercent!, showWord: false),
              sub: s.deltaPercent == null ? 'fără comparație' : '${s.deltaPercent! <= 0 ? 'mai bine' : 'mai rău'} față de perioada trecută',
            ),
            MetricTile(
              label: 'Peste prag',
              value: s.overThreshold == null ? '—' : '${s.overThreshold!.round()} %',
              sub: 'din timpul înregistrat · prag $threshold',
            ),
            MetricTile(
              label: 'Aderență',
              value: d.adherence == null ? '—' : '${d.adherence} %',
              sub: d.adherence == null ? 'adaugă medicamente în Remindere' : 'doze luate la timp',
            ),
            MetricTile(
              label: 'Teste făcute',
              value: _period == Period.day ? '${s.testDays}' : '${s.testDays} din ${s.range.days}',
              sub: _period == Period.day ? 'evaluări azi' : 'zile cu evaluare',
            ),
          ],
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(switch (_period) {
                Period.day => 'Indicele pe ore',
                Period.week => 'Indicele pe zile',
                Period.month => 'Luna dintr-o privire',
              }, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              Text(switch (_period) {
                Period.day => 'pastilele de sub bare = doze luate',
                Period.week => 'media fiecărei zile, din 100',
                Period.month => 'fiecare zi, colorată după media ei',
              }, style: TextStyle(fontSize: 15, color: AppColors.textMuted)),
              const SizedBox(height: 10),
              if (_period == Period.month)
                MonthHeatmap(cells: s.cells, leadingBlanks: s.leadingBlanks)
              else
                IndexBarChart(
                  bars: [for (final b in s.bars) BarDatum(b.label, b.value, highlight: b.highlight, dose: b.dose)],
                  threshold: threshold,
                  semanticsLabel: [
                    for (final b in s.bars)
                      if (b.value != null) '${b.label.isEmpty ? '' : b.label}: ${b.value!.round()}',
                  ].join(', '),
                ),
            ],
          ),
        ),
        if (d.tapping.length >= 2) ...[const SizedBox(height: 12), TappingCard(rates: d.tapping)],
        if (d.insights.isNotEmpty) ...[
          const SizedBox(height: 12),
          AppCard(
            color: AppColors.surfaceRaised,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(12)),
                      child: Icon(Symbols.lightbulb_rounded, color: AppColors.accentDark),
                    ),
                    const SizedBox(width: 10),
                    const Text('Perspective', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 10),
                for (final i in d.insights)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(i, style: const TextStyle(fontSize: 17, height: 1.4)),
                  ),
                Text('Observații din datele tale, nu sfaturi medicale.', style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
        const SizedBox(height: 18),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 8,
          children: [
            const SectionLabel(S.sessions),
            SizedBox(
              width: 260,
              child: AppSegmented<_Filter>(
                height: 46,
                options: const [Choice(_Filter.all, 'Toate'), Choice(_Filter.tests, 'Evaluări'), Choice(_Filter.free, 'Libere')],
                selected: _filter,
                onChanged: (v) => setState(() => _filter = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (shown.isEmpty)
          EmptyState(icon: Symbols.insights_rounded, text: demo ? S.noSessionsDemo : S.noSessions)
        else
          for (final x in shown.take(40)) ...[SessionTile(session: x), const SizedBox(height: 10)],
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton.outlined(
      tooltip: label,
      constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
      style: IconButton.styleFrom(
        side: BorderSide(color: AppColors.border),
        backgroundColor: AppColors.surface,
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 26),
    );
  }
}

/// Tapping-ul din teste: ultima valoare, diferența față de media celor dinainte și evoluția.
class TappingCard extends StatelessWidget {
  const TappingCard({super.key, required this.rates});
  final List<double> rates;

  @override
  Widget build(BuildContext context) {
    final last = rates.last;
    final before = rates.sublist(0, rates.length - 1);
    final avg = before.reduce((a, b) => a + b) / before.length;
    final delta = avg == 0 ? 0 : ((last - avg) / avg * 100).round();
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: SectionLabel('Tapping cu mănușa')),
              DeltaBadge(percent: delta, lowerIsBetter: false),
            ],
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              text: last.toStringAsFixed(1).replaceAll('.', ','),
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, fontFeatures: tabular),
              children: [
                TextSpan(
                  text: '  atingeri/s · ultimele ${rates.length} teste',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // 6 atingeri/s = sus; graficul folosește aceeași scară 0–100 ca restul.
          TrendChart(
            values: [for (final r in rates) (r / 6 * 100).clamp(0, 100).toDouble()],
            height: 56,
            semanticsLabel: 'Tapping în ultimele teste',
          ),
        ],
      ),
    );
  }
}

/// Rândul unei sesiuni; [readOnly] = fără detaliu (pacienții demo ai medicului).
class SessionTile extends StatelessWidget {
  const SessionTile({super.key, required this.session, this.readOnly = false});

  final SessionRecord session;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final kind = switch (s.kind) {
      SessionKind.assessment => 'Evaluare completă',
      SessionKind.test => 'Test',
      SessionKind.free => 'Înregistrare liberă',
    };
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), boxShadow: AppShadows.card),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.cardBorder),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: readOnly
              ? null
              : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SessionDetailScreen(sessionId: s.id))),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 76),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(Fmt.dayAndTime(s.startedAt), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        Text(
                          [kind, Fmt.duration(s.duration), if (s.avgFrequency != null) '${Fmt.hz(s.avgFrequency!)} Hz'].join(' · '),
                          style: TextStyle(fontSize: 15, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SeverityChip(Severity.fromIndex(s.avgIndex), prefix: '${s.avgIndex}'),
                  const SizedBox(width: 4),
                  if (!readOnly) Icon(Symbols.chevron_right_rounded, color: AppColors.textMuted, size: 26),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
