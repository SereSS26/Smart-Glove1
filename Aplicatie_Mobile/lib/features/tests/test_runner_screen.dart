import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/contract.dart';
import '../../core/glove_source.dart';
import '../../core/live_packet.dart';
import '../../core/tests.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/db/models.dart';
import '../../data/simulated_glove.dart';
import '../../services/tapping.dart';
import '../../state/providers.dart';
import '../../ui/ui.dart';
import 'test_result_screen.dart';
import 'test_widgets.dart';
import '../../services/feedback.dart';

/// Un pas terminat: rezultatul de salvat și eșantioanele pe secundă (pentru Istoric).
class StepOutcome {
  const StepOutcome({required this.kind, required this.result, required this.samples, this.tapping});
  final TestKind kind;
  final TestResultRecord result;
  final List<SampleRecord> samples;
  final TappingResult? tapping;
}

enum _Phase { intro, countdown, recording, result }

/// Testul pas cu pas: instrucțiune → 3-2-1 → înregistrare cu inel de timp → semnal la final → rezultat.
class TestRunnerScreen extends ConsumerStatefulWidget {
  const TestRunnerScreen({super.key, required this.tests});

  final List<TestKind> tests;

  @override
  ConsumerState<TestRunnerScreen> createState() => _TestRunnerScreenState();
}

class _TestRunnerScreenState extends ConsumerState<TestRunnerScreen> {
  int _step = 0;
  _Phase _phase = _Phase.intro;
  int _count = 3;
  DateTime? _started;
  double _elapsed = 0;
  Timer? _timer;
  StreamSubscription<LivePacket>? _sub;
  final _packets = <(DateTime, LivePacket)>[];
  final _outcomes = <StepOutcome>[];

  // Tapping pe ecran.
  int _next = 0;
  final _tapTimes = <double>[];
  int _misses = 0;

  TestKind get _kind => widget.tests[_step];

  /// Mănușa folosită la test, ținută aici ca s-o putem opri și după ce ecranul se închide.
  late final GloveSource _glove;

  @override
  void initState() {
    super.initState();
    _glove = ref.read(gloveSourceProvider);
    _voice = ref.read(voiceGuideProvider);
    _wakelock(true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _announce());
  }

  late final VoiceGuide _voice;

  /// Ghidarea vocală: titlul și instrucțiunea pasului.
  void _announce() => _voice.say('${_kind.title}. ${_kind.instruction}');

  @override
  void dispose() {
    _timer?.cancel();
    _sub?.cancel();
    _setSimulatedTest(null);
    _wakelock(false);
    _voice.stop();
    super.dispose();
  }

  Future<void> _wakelock(bool on) async {
    try {
      on ? await WakelockPlus.enable() : await WakelockPlus.disable();
    } catch (_) {
      // Fără ecran ținut aprins (ex. în teste).
    }
  }

  void _setSimulatedTest(TestKind? kind) {
    final source = _glove;
    if (source is SimulatedGlove) source.setTest(kind);
  }

  void _startCountdown() {
    setState(() {
      _phase = _Phase.countdown;
      _count = 3;
    });
    HapticFeedback.selectionClick();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_count <= 1) {
        t.cancel();
        _startRecording();
      } else {
        HapticFeedback.selectionClick();
        setState(() => _count--);
      }
    });
  }

  void _startRecording() {
    _packets.clear();
    _tapTimes.clear();
    _misses = 0;
    _next = 0;
    _setSimulatedTest(_kind);
    _started = DateTime.now();
    _elapsed = 0;
    HapticFeedback.heavyImpact();
    _voice.say('Acum.');
    _sub = _glove.packets.listen((p) => _packets.add((DateTime.now(), p)));
    setState(() => _phase = _Phase.recording);
    // Timpul se numără în pași de 0,1 s (merge la fel pe telefon și în teste).
    _timer = Timer.periodic(const Duration(milliseconds: 100), (t) {
      final e = t.tick / 10;
      if (e >= _kind.seconds) {
        t.cancel();
        _finishStep();
      } else {
        setState(() => _elapsed = e);
      }
    });
  }

  void _stopEarly() {
    _timer?.cancel();
    _sub?.cancel();
    _setSimulatedTest(null);
    setState(() => _phase = _Phase.intro);
  }

  void _finishStep() {
    _sub?.cancel();
    _setSimulatedTest(null);
    HapticFeedback.heavyImpact();
    SystemSound.play(SystemSoundType.alert);
    _voice.say('Gata.');
    final end = DateTime.now();
    final kind = _kind;
    final packets = [..._packets];

    // Un eșantion pe secundă, ca la sesiunile obișnuite.
    final samples = <SampleRecord>[
      for (var i = 0; i < packets.length; i += GloveContract.packetsPerSecond)
        SampleRecord(
          at: packets[i].$1,
          frequency: packets[i].$2.frequencyHz,
          rms: packets[i].$2.rmsDps,
          index: packets[i].$2.tremorIndex,
          state: kind.state,
          fingers: packets[i].$2.fingers,
        ),
    ];

    late TestResultRecord result;
    TappingResult? tapping;
    if (kind.isTremor) {
      final idx = [for (final p in packets) p.$2.tremorIndex.toDouble()];
      final freqs = [for (final p in packets) p.$2.frequencyHz].where((f) => f > 0).toList();
      final avg = idx.isEmpty ? 0.0 : idx.reduce((a, b) => a + b) / idx.length;
      result = TestResultRecord(
        test: kind.id,
        startedAt: _started!,
        endedAt: end,
        value: avg.roundToDouble(),
        metrics: {
          'avg': avg.round(),
          'max': idx.isEmpty ? 0 : idx.reduce((a, b) => a > b ? a : b).round(),
          'freq': freqs.isEmpty ? 0 : double.parse((freqs.reduce((a, b) => a + b) / freqs.length).toStringAsFixed(2)),
        },
        trace: [for (final s in samples) s.index],
      );
    } else if (kind == TestKind.tappingGlove) {
      // Arătătorul (F2); dacă nu e calibrat, degetul mare (F1).
      final finger = packets.any((p) => p.$2.fingers.length > 1 && p.$2.fingers[1] != null) ? 1 : 0;
      final signal = [for (final p in packets) (p.$2.fingers[finger] ?? 0).toDouble()];
      tapping = analyzeTapping(signal, hz: GloveContract.packetsPerSecond.toDouble());
      result = TestResultRecord(
        test: kind.id,
        startedAt: _started!,
        endedAt: end,
        value: double.parse(tapping.rate.toStringAsFixed(2)),
        metrics: tapping.toMetrics(),
        trace: [for (final v in signal) v.round()],
      );
    } else {
      tapping = analyzeScreenTapping(_tapTimes, duration: kind.seconds.toDouble(), misses: _misses);
      result = TestResultRecord(
        test: kind.id,
        startedAt: _started!,
        endedAt: end,
        value: double.parse(tapping.rate.toStringAsFixed(2)),
        metrics: {...tapping.toMetrics(), 'misses': _misses},
        trace: [for (final t in _tapTimes) double.parse(t.toStringAsFixed(2))],
      );
    }
    _outcomes.removeWhere((o) => o.kind == kind);
    _outcomes.add(StepOutcome(kind: kind, result: result, samples: samples, tapping: tapping));
    setState(() => _phase = _Phase.result);
  }

  void _nextStep() {
    if (_step < widget.tests.length - 1) {
      setState(() {
        _step++;
        _phase = _Phase.intro;
      });
      _announce();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => TestResultScreen(tests: widget.tests, outcomes: [..._outcomes]),
        ),
      );
    }
  }

  Future<void> _close() async {
    if (_outcomes.isEmpty && _phase == _Phase.intro) {
      Navigator.of(context).pop();
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Renunți la test?'),
        content: const Text('Ce ai înregistrat până acum nu se salvează.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Continui testul')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(120, 52)),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Renunț'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final multi = widget.tests.length > 1;
    final stepProgress = switch (_phase) {
      _Phase.intro || _Phase.countdown => 0.05,
      _Phase.recording => (_elapsed / _kind.seconds).clamp(0.05, 1.0),
      _Phase.result => 1.0,
    };
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Scaffold(
        body: SafeArea(
          child: FillOrScroll(
            padding: const EdgeInsets.fromLTRB(AppSizes.pagePadding, 12, AppSizes.pagePadding, 16),
            minHeight: 720,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        multi ? 'Evaluare · pasul ${_step + 1} din ${widget.tests.length}' : 'Test',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textMuted),
                      ),
                    ),
                    IconButton.outlined(
                      iconSize: 24,
                      constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
                      style: IconButton.styleFrom(side: BorderSide(color: AppColors.border)),
                      onPressed: _close,
                      icon: const Icon(Symbols.close_rounded, semanticLabel: 'Închide testul'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (multi) ...[StepBar(count: widget.tests.length, current: _step, progress: stepProgress), const SizedBox(height: 14)],
                Text(_kind.title, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, height: 1.15)),
                const SizedBox(height: 6),
                Text(_kind.instruction, style: const TextStyle(fontSize: 20, height: 1.35)),
                const SizedBox(height: 16),
                Expanded(child: _body()),
                const SizedBox(height: 12),
                ..._actions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    switch (_phase) {
      case _Phase.intro:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 168,
                height: 168,
                decoration: BoxDecoration(color: AppColors.accentSoft, shape: BoxShape.circle),
                child: Icon(testIcon(_kind), size: 88, color: AppColors.accentDark),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [_chip(Symbols.timer_rounded, '${_kind.seconds} secunde'), _chip(Symbols.volume_up_rounded, 'semnal la final')],
              ),
            ],
          ),
        );
      case _Phase.countdown:
        return Center(
          child: Semantics(
            liveRegion: true,
            label: 'Începe în $_count',
            excludeSemantics: true,
            child: Text(
              '$_count',
              style: TextStyle(fontSize: 120, fontWeight: FontWeight.w800, color: AppColors.accent),
            ),
          ),
        );
      case _Phase.recording:
        final left = (_kind.seconds - _elapsed).ceil().clamp(0, _kind.seconds);
        final live = ref.watch(liveProvider);
        final p = live.stale ? null : live.packet;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_kind == TestKind.tappingScreen) ...[
              TapTargets(
                next: _next,
                enabled: true,
                onHit: (i) {
                  Haptics.selection();
                  setState(() {
                    _tapTimes.add(_elapsed);
                    _next = 1 - i;
                  });
                },
                onMiss: () => setState(() => _misses++),
              ),
              const SizedBox(height: 12),
              Text('$left s · atingeri: ${_tapTimes.length}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            ] else ...[
              CountdownRing(fraction: 1 - _elapsed / _kind.seconds, label: '$left', caption: 'secunde rămase'),
              const SizedBox(height: 14),
              if (_kind.isTremor && p != null)
                SeverityChip(Severity.fromIndex(p.tremorIndex), prefix: 'acum: indice ${p.tremorIndex}')
              else if (_kind == TestKind.tappingGlove)
                _chip(Symbols.pinch_rounded, 'atingeri până acum: ${_liveTaps()}'),
            ],
          ],
        );
      case _Phase.result:
        final o = _outcomes.firstWhere((o) => o.kind == _kind);
        return Center(child: _StepResult(outcome: o));
    }
  }

  int _liveTaps() {
    if (_packets.length < 4) return 0;
    final finger = _packets.any((p) => p.$2.fingers.length > 1 && p.$2.fingers[1] != null) ? 1 : 0;
    return analyzeTapping([for (final p in _packets) (p.$2.fingers[finger] ?? 0).toDouble()]).taps;
  }

  List<Widget> _actions() {
    switch (_phase) {
      case _Phase.intro:
        return [GradientButton(label: 'Încep', icon: Symbols.play_arrow_rounded, onPressed: _startCountdown)];
      case _Phase.countdown:
        return [const SizedBox(height: AppSizes.buttonHeight)];
      case _Phase.recording:
        return [
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.recording,
              side: BorderSide(color: AppColors.recordingBorder, width: 2),
              minimumSize: const Size.fromHeight(AppSizes.buttonHeight),
            ),
            onPressed: _stopEarly,
            icon: const Icon(Symbols.stop_rounded, fill: 1),
            label: const Text('Oprește'),
          ),
        ];
      case _Phase.result:
        final last = _step == widget.tests.length - 1;
        return [
          GradientButton(label: last ? 'Vezi rezultatul' : 'Continuă', icon: Symbols.arrow_forward_rounded, onPressed: _nextStep),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: () => setState(() => _phase = _Phase.intro),
            icon: const Icon(Symbols.replay_rounded),
            label: const Text('Refă pasul'),
          ),
        ];
    }
  }

  Widget _chip(IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textMuted),
        ),
      ],
    ),
  );
}

class _StepResult extends StatelessWidget {
  const _StepResult({required this.outcome});
  final StepOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final k = outcome.kind;
    final r = outcome.result;
    if (k.isTremor) {
      final v = r.value.round();
      final freq = r.metrics['freq'] ?? 0;
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TremorRing(index: v, threshold: 60, size: 150),
          const SizedBox(height: 12),
          SeverityChip(Severity.fromIndex(v)),
          const SizedBox(height: 8),
          Text(
            freq > 0 ? 'frecvență ${freq.toStringAsFixed(1).replaceAll('.', ',')} Hz · maxim ${r.metrics['max']}' : 'fără tremor măsurabil',
            style: TextStyle(fontSize: 17, color: AppColors.textMuted),
          ),
        ],
      );
    }
    final t = outcome.tapping!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          t.rate.toStringAsFixed(1).replaceAll('.', ','),
          style: const TextStyle(fontSize: 72, fontWeight: FontWeight.w800, height: 1, fontFeatures: tabular),
        ),
        Text('atingeri pe secundă', style: TextStyle(fontSize: 18, color: AppColors.textMuted)),
        const SizedBox(height: 12),
        Text(
          '${t.taps} atingeri · ${t.rhythmLabel}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        if (k == TestKind.tappingGlove)
          Text(
            'deschidere ${t.amplitude.round()} % · oboseală ${(t.fatigue * 100).round()} %',
            style: TextStyle(fontSize: 16, color: AppColors.textMuted),
          )
        else
          Text('precizie ${t.amplitude.round()} %', style: TextStyle(fontSize: 16, color: AppColors.textMuted)),
      ],
    );
  }
}
