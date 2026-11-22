import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../app.dart';
import '../../core/glove_source.dart';
import '../../core/tests.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/db/models.dart';
import '../../state/providers.dart';
import '../session/session_screen.dart';
import 'test_runner_screen.dart';
import 'test_widgets.dart';

/// Ultimul rezultat al fiecărui test (pentru „ultima dată: 42”).
final lastResultsProvider = FutureProvider.autoDispose<Map<TestKind, TestResultRecord>>((ref) async {
  final db = ref.watch(databaseProvider);
  final simulated = ref.watch(settingsProvider.select((s) => s.demoMode));
  final out = <TestKind, TestResultRecord>{};
  for (final t in TestKind.values) {
    final r = await db.resultsOf(t.id, simulated: simulated, limit: 1);
    if (r.isNotEmpty) out[t] = r.first;
  }
  return out;
});

/// „Ce verificăm azi?”: evaluarea completă, un singur test sau înregistrarea liberă.
class TestPickerScreen extends ConsumerWidget {
  const TestPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final last = ref.watch(lastResultsProvider).value ?? const {};
    final connected = ref.watch(connectionProvider).value == GloveConnection.connected && !ref.watch(liveProvider).stale;

    void run(List<TestKind> tests) {
      if (tests.any((t) => t.needsGlove) && !connected) {
        showMessage('Conectează mănușa ca să faci testul. Tapping pe ecran merge și fără ea.');
        return;
      }
      Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => TestRunnerScreen(tests: tests)));
    }

    Future<void> free() async {
      if (!connected) {
        showMessage('Conectează mănușa ca să înregistrezi.');
        return;
      }
      await ref.read(sessionProvider.notifier).start();
      if (context.mounted) Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => const SessionScreen()));
    }

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppSizes.pagePadding, 16, AppSizes.pagePadding, 24),
          children: [
            const BackHeader(title: 'Ce verificăm azi?', subtitle: 'Evaluarea completă sau un singur test'),
            const SizedBox(height: 16),
            _AssessmentCard(last: last, onStart: () => run(TestKind.assessment)),
            const SizedBox(height: 18),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: SectionLabel('Sau un singur test')),
            const SizedBox(height: 10),
            for (final t in TestKind.values) ...[
              _TestRow(
                icon: testIcon(t),
                title: t.title,
                subtitle:
                    '${t.seconds} s · ${last[t] == null ? (t.needsGlove ? 'cu mănușa' : 'merge și fără mănușă') : 'ultima dată: ${formatTestValue(t, last[t]!.value)}'}',
                onTap: () => run([t]),
              ),
              const SizedBox(height: 10),
            ],
            _TestRow(
              icon: Symbols.radio_button_checked_rounded,
              title: 'Înregistrare liberă',
              subtitle: 'cât vrei · cu note și momente marcate',
              onTap: free,
            ),
          ],
        ),
      ),
    );
  }
}

class _AssessmentCard extends StatelessWidget {
  const _AssessmentCard({required this.last, required this.onStart});

  final Map<TestKind, TestResultRecord> last;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final tremor = [for (final t in TestKind.assessment.where((t) => t.isTremor)) last[t]?.value].whereType<double>().toList();
    final lastLine = tremor.isEmpty
        ? 'Prima evaluare: durează cam 3 minute.'
        : 'Ultima: tremor ${(tremor.reduce((a, b) => a + b) / tremor.length).round()} · ${Severity.fromIndex((tremor.reduce((a, b) => a + b) / tremor.length).round()).label}';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: AppColors.gradient, borderRadius: BorderRadius.circular(26), boxShadow: AppShadows.button),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'EVALUARE COMPLETĂ',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 1.1, color: Colors.white),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(999)),
                child: const Text(
                  'recomandat zilnic',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            '4 teste · aproximativ 3 minute',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white, height: 1.2),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < TestKind.assessment.length; i++)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(999)),
                  child: Text(
                    '${i + 1} · ${testShortName(TestKind.assessment[i])}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(lastLine, style: const TextStyle(fontSize: 15, color: Colors.white)),
          const SizedBox(height: 14),
          Material(
            color: AppColors.isDark ? const Color(0xFFFFE3EE) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onStart,
              child: SizedBox(
                height: 60,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Symbols.play_arrow_rounded, fill: 1, color: AppColors.isDark ? const Color(0xFF7A1F47) : const Color(0xFFA3214F)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Începe evaluarea',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.isDark ? const Color(0xFF7A1F47) : const Color(0xFFA3214F),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TestRow extends StatelessWidget {
  const _TestRow({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: AppColors.accentSoft, borderRadius: BorderRadius.circular(14)),
                    child: Icon(icon, color: AppColors.accentDark),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        Text(subtitle, style: TextStyle(fontSize: 15, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  Icon(Symbols.chevron_right_rounded, color: AppColors.textMuted, size: 26),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
