import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../app.dart';
import '../../core/format.dart';
import '../../core/tests.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/db/models.dart';
import '../../state/providers.dart';
import '../../ui/ui.dart';
import 'test_picker_screen.dart';
import 'test_runner_screen.dart';
import 'test_widgets.dart';

/// Rezultatul evaluării (sau al unui test): tremorul, tapping-ul, comparația cu data trecută și două întrebări.
class TestResultScreen extends ConsumerStatefulWidget {
  const TestResultScreen({super.key, required this.tests, required this.outcomes});

  final List<TestKind> tests;
  final List<StepOutcome> outcomes;

  @override
  ConsumerState<TestResultScreen> createState() => _TestResultScreenState();
}

class _TestResultScreenState extends ConsumerState<TestResultScreen> {
  Map<TestKind, double> _previous = const {};
  bool? _tookMeds;
  String? _feeling;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadPrevious();
  }

  Future<void> _loadPrevious() async {
    final db = ref.read(databaseProvider);
    final simulated = ref.read(settingsProvider).demoMode;
    final out = <TestKind, double>{};
    for (final o in widget.outcomes) {
      final r = await db.resultsOf(o.kind.id, simulated: simulated, limit: 1);
      if (r.isNotEmpty) out[o.kind] = r.first.value;
    }
    if (mounted) setState(() => _previous = out);
  }

  int? _delta(TestKind k, double v) {
    final p = _previous[k];
    if (p == null || p == 0) return null;
    return ((v - p) / p * 100).round();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    final simulated = ref.read(settingsProvider).demoMode;
    final first = widget.outcomes.first;
    final id = await db.startSession(
      at: first.result.startedAt,
      activity: first.kind.state,
      simulated: simulated,
      kind: widget.tests.length > 1 ? SessionKind.assessment : SessionKind.test,
    );
    for (final o in widget.outcomes) {
      await db.addSamples(id, o.samples);
      await db.addTestResult(id, o.result);
    }
    final note = [
      if (_tookMeds != null) _tookMeds! ? 'Medicamentul luat azi' : 'Medicamentul nu e luat azi',
      if (_feeling != null) 'Stare: $_feeling',
    ].join(' · ');
    if (note.isNotEmpty) await db.setNote(id, note);
    await db.finishSession(id, at: widget.outcomes.last.result.endedAt);
    ref.invalidate(historyProvider);
    ref.invalidate(lastResultsProvider);
    if (!mounted) return;
    Navigator.of(context).popUntil((r) => r.isFirst);
    ref.read(patientTabProvider.notifier).go(Tabs.history);
    showMessage('Evaluarea e salvată în Istoric.');
  }

  @override
  Widget build(BuildContext context) {
    final tremor = widget.outcomes.where((o) => o.kind.isTremor).toList();
    final tremorAvg = tremor.isEmpty ? null : tremor.map((o) => o.result.value).reduce((a, b) => a + b) / tremor.length;
    final prevTremor = [for (final o in tremor) _previous[o.kind]].whereType<double>().toList();
    final tremorDelta = tremorAvg == null || prevTremor.length != tremor.length || prevTremor.isEmpty
        ? null
        : ((tremorAvg - prevTremor.reduce((a, b) => a + b) / prevTremor.length) /
                  (prevTremor.reduce((a, b) => a + b) / prevTremor.length) *
                  100)
              .round();
    final threshold = ref.watch(settingsProvider.select((s) => s.alertThreshold));

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSizes.pagePadding, 16, AppSizes.pagePadding, 24),
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(color: AppColors.okBg, shape: BoxShape.circle),
                  child: Icon(Symbols.check_rounded, color: AppColors.ok, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.tests.length > 1 ? 'Evaluare gata' : '${widget.tests.first.title}: gata',
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.15),
                      ),
                      Text(
                        Fmt.longDate(widget.outcomes.first.result.startedAt),
                        style: TextStyle(fontSize: 15, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (tremorAvg != null) ...[
              AppCard(
                child: Row(
                  children: [
                    TremorRing(index: tremorAvg.round(), threshold: threshold, size: 112),
                    const SizedBox(width: 18),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionLabel('Tremor'),
                          const SizedBox(height: 8),
                          SeverityChip(Severity.fromIndex(tremorAvg.round())),
                          const SizedBox(height: 8),
                          if (tremorDelta != null) ...[
                            DeltaBadge(percent: tremorDelta),
                            const SizedBox(height: 4),
                            Text('față de evaluarea anterioară', style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
                          ] else
                            Text('prima evaluare: baza de comparație', style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Column(
                children: [
                  for (var i = 0; i < widget.outcomes.length; i++) ...[
                    if (i > 0) Divider(color: AppColors.divider),
                    _row(widget.outcomes[i]),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Ai luat medicamentul azi?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  ChoiceTiles<bool?>(
                    options: const [Choice(true, 'Da'), Choice(false, 'Nu')],
                    selected: _tookMeds,
                    onChanged: (v) => setState(() => _tookMeds = v),
                  ),
                  const SizedBox(height: 16),
                  const Text('Cum te simți?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  ChoiceTiles<String?>(
                    height: 76,
                    options: const [
                      Choice('bine', 'Bine', icon: Symbols.sentiment_satisfied_rounded),
                      Choice('așa și așa', 'Așa și așa', icon: Symbols.sentiment_neutral_rounded),
                      Choice('rău', 'Rău', icon: Symbols.sentiment_dissatisfied_rounded),
                    ],
                    selected: _feeling,
                    onChanged: (v) => setState(() => _feeling = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            GradientButton(label: _saving ? 'Se salvează…' : 'Salvează', icon: Symbols.task_alt_rounded, onPressed: _saving ? null : _save),
            const SizedBox(height: 10),
            OutlinedButton(onPressed: _saving ? null : () => Navigator.of(context).pop(), child: const Text('Renunță, nu salva')),
          ],
        ),
      ),
    );
  }

  Widget _row(StepOutcome o) {
    final k = o.kind;
    final v = o.result.value;
    final detail = k.isTremor
        ? 'indice ${v.round()} · ${Severity.fromIndex(v.round()).label}'
        : '${formatTestValue(k, v)} · ${o.tapping?.rhythmLabel ?? ''}';
    final d = _delta(k, v);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 60),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(k.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                Text(detail, style: TextStyle(fontSize: 15, color: AppColors.textMuted)),
              ],
            ),
          ),
          if (d != null) DeltaBadge(percent: d, lowerIsBetter: k.isTremor, showWord: false),
        ],
      ),
    );
  }
}
