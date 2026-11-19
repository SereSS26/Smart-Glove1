import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/db/models.dart';
import '../../state/providers.dart';
import 'charts.dart';
import 'session_detail_screen.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  bool _week = true;

  static const _dayLetters = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  /// Media indicelui pe zi (ultimele 7 zile, azi la dreapta), ponderată cu durata sesiunilor.
  List<BarDatum> _weekBars(List<SessionRecord> sessions, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return [
      for (var d = 6; d >= 0; d--)
        () {
          final day = today.subtract(Duration(days: d));
          final inDay = sessions.where((s) => DateTime(s.startedAt.year, s.startedAt.month, s.startedAt.day) == day);
          return BarDatum(_dayLetters[day.weekday - 1], _weighted(inDay), highlight: d == 0);
        }(),
    ];
  }

  /// Media pe oră pentru azi, de la 6 la 23.
  List<BarDatum> _dayBars(List<SessionRecord> sessions, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return [
      for (var h = 6; h <= 23; h++)
        BarDatum('$h', _weighted(sessions.where((s) => s.startedAt.isAfter(today) && s.startedAt.hour == h)), highlight: h == now.hour),
    ];
  }

  static double? _weighted(Iterable<SessionRecord> list) {
    var total = 0.0, weight = 0.0;
    for (final s in list) {
      final w = s.duration.inSeconds.clamp(1, 1 << 30).toDouble();
      total += s.avgIndex * w;
      weight += w;
    }
    return weight == 0 ? null : total / weight;
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(historyProvider);
    final threshold = ref.watch(settingsProvider.select((s) => s.alertThreshold));
    final demo = ref.watch(settingsProvider.select((s) => s.demoMode));
    final now = DateTime.now();

    return RefreshIndicator(
      onRefresh: () => ref.refresh(historyProvider.future),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSizes.pagePadding, 14, AppSizes.pagePadding, 20),
        children: [
          // Wrap: cu text mărit, butoanele Zi/Săptămână trec sub titlu în loc să iasă din ecran.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              Text(S.historyTitle, style: Theme.of(context).textTheme.headlineMedium),
              SegmentedButton<bool>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  minimumSize: const Size(0, 52),
                  textStyle: const TextStyle(fontFamily: 'Atkinson', fontSize: 17, fontWeight: FontWeight.w700),
                  selectedBackgroundColor: AppColors.accentSoft,
                  selectedForegroundColor: AppColors.accentDark,
                ),
                segments: const [
                  ButtonSegment(value: false, label: Text(S.day)),
                  ButtonSegment(value: true, label: Text(S.week)),
                ],
                selected: {_week},
                onSelectionChanged: (v) => setState(() => _week = v.first),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (demo) ...[const SimulatedBanner('SESIUNI SIMULATE · mod demonstrativ'), const SizedBox(height: 12)],
          history.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Text('Nu am putut citi istoricul: $e'),
            data: (sessions) {
              final bars = _week ? _weekBars(sessions, now) : _dayBars(sessions, now);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(S.tremorIndex, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                        Text(_week ? S.dayAverage : S.hourAverage, style: TextStyle(fontSize: 16, color: AppColors.textMuted)),
                        const SizedBox(height: 8),
                        IndexBarChart(
                          bars: bars,
                          threshold: threshold,
                          semanticsLabel: [
                            for (final b in bars)
                              if (b.value != null) '${b.label}: ${b.value!.round()}',
                          ].join(', '),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const SectionLabel(S.sessions),
                  const SizedBox(height: 10),
                  if (sessions.isEmpty)
                    Text(demo ? S.noSessionsDemo : S.noSessions, style: TextStyle(fontSize: 18, color: AppColors.textMuted))
                  else
                    for (final s in sessions.take(50)) ...[_SessionTile(session: s), const SizedBox(height: 10)],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  const _SessionTile({required this.session});

  final SessionRecord session;

  @override
  Widget build(BuildContext context) {
    final s = session;
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SessionDetailScreen(sessionId: s.id))),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 80),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(Fmt.dayAndTime(s.startedAt), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                      Text(
                        [
                          Fmt.duration(s.duration),
                          s.activity.label,
                          if (s.avgFrequency != null) '${Fmt.hz(s.avgFrequency!)} Hz',
                        ].join(' · '),
                        style: TextStyle(fontSize: 16, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                _IndexChip(index: s.avgIndex),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded, color: AppColors.textMuted, size: 28),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IndexChip extends StatelessWidget {
  const _IndexChip({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final sev = Severity.fromIndex(index);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: sev.background, borderRadius: BorderRadius.circular(14)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: sev.dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            '$index · ${sev.label}',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: sev.foreground),
          ),
        ],
      ),
    );
  }
}
