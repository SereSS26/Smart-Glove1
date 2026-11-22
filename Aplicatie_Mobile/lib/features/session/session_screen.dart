import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../app.dart';
import '../../core/contract.dart';
import '../../core/format.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../state/providers.dart';
import '../../ui/ui.dart';
import '../history/session_detail_screen.dart';

/// Sesiunea în curs: cronometru, tremorul pe scurt, activitatea, note și oprire.
class SessionScreen extends ConsumerStatefulWidget {
  const SessionScreen({super.key});

  @override
  ConsumerState<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends ConsumerState<SessionScreen> {
  late final Timer _clock;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  Future<void> _stop() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text(S.stopConfirmTitle),
        content: const Text(S.stopConfirmBody, style: TextStyle(fontSize: 18)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text(S.keepRecording, style: TextStyle(fontSize: 18)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              minimumSize: const Size(120, 56),
              backgroundColor: AppColors.recording,
              foregroundColor: AppColors.isDark ? AppPalette.dark.onAccent : Colors.white,
            ),
            onPressed: () => Navigator.pop(c, true),
            child: const Text(S.stopSession, style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final record = await ref.read(sessionProvider.notifier).stop();
    if (!mounted || record == null) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => SessionDetailScreen(sessionId: record.id)));
  }

  Future<void> _addNote() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text(S.addNote),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          style: const TextStyle(fontSize: 19),
          decoration: const InputDecoration(hintText: S.notePlaceholder),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text(S.cancel, style: TextStyle(fontSize: 18)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(120, 56)),
            onPressed: () => Navigator.pop(c, controller.text),
            child: const Text(S.save, style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
    if (text == null || text.trim().isEmpty) return;
    await ref.read(sessionProvider.notifier).addNote(text);
    showMessage(S.noteSaved);
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final live = ref.watch(liveProvider);
    final simulated = ref.watch(gloveSourceProvider.select((s) => s.isSimulated));
    final threshold = ref.watch(settingsProvider.select((s) => s.alertThreshold));
    if (session == null) return const Scaffold();
    final p = live.stale ? null : live.packet;
    final muted = TextStyle(fontSize: 17, color: AppColors.textMuted);

    // Ieșirea din ecran nu oprește sesiunea; butonul de jos din Live duce înapoi aici.
    return Scaffold(
      body: SafeArea(
        child: FillOrScroll(
          padding: const EdgeInsets.fromLTRB(AppSizes.pagePadding, 16, AppSizes.pagePadding, 20),
          minHeight: 700,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (simulated) ...[const SimulatedBanner(S.simulatedBanner), const SizedBox(height: 10)],
              // Antet roșu: înregistrare + cronometru. Săgeata duce înapoi la Live, sesiunea continuă.
              Container(
                constraints: const BoxConstraints(minHeight: 64),
                padding: const EdgeInsets.only(left: 6, right: 20),
                decoration: BoxDecoration(
                  color: AppColors.recordingSoft,
                  borderRadius: BorderRadius.circular(AppSizes.radius),
                  border: Border.all(color: AppColors.recordingBorder),
                ),
                child: Row(
                  children: [
                    IconButton(
                      iconSize: 26,
                      constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(
                        Symbols.arrow_back_rounded,
                        color: AppColors.recordingText,
                        semanticLabel: 'Înapoi la Live, sesiunea continuă',
                      ),
                    ),
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(color: AppColors.recording, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 12),
                    // Cu text mărit, eticheta și cronometrul se micșorează cât să încapă pe rând.
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          S.recording.toUpperCase(),
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: 1.3, color: AppColors.recordingText),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        Fmt.clock(DateTime.now().difference(session.startedAt)),
                        style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, fontFeatures: tabular, color: AppColors.recordingText),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            if (p != null && p.hasTremor)
                              Text(
                                Fmt.hz(p.frequencyHz),
                                style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w800, height: 1, fontFeatures: tabular),
                              )
                            else
                              // Fără tremor sau fără date: o liniuță discretă, nu o cifră mare.
                              Text(
                                '–',
                                style: TextStyle(fontSize: 44, fontWeight: FontWeight.w700, height: 1.18, color: AppColors.textMuted),
                              ),
                            const SizedBox(width: 8),
                            if (p != null && p.hasTremor)
                              Text(
                                'Hz',
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textMuted),
                              ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (p != null) SeverityChip(Severity.fromIndex(p.tremorIndex)) else Text(S.noData, style: muted),
                            const SizedBox(height: 6),
                            Text.rich(
                              TextSpan(
                                text: '${S.index} ',
                                style: muted,
                                children: [
                                  TextSpan(
                                    text: p == null ? '—' : '${p.tremorIndex}',
                                    style: TextStyle(color: AppColors.text, fontWeight: FontWeight.w700),
                                  ),
                                  const TextSpan(text: '/100'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TrendChart(values: live.history, threshold: threshold, height: 64),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const SectionLabel(S.whatAreYouDoing),
              const SizedBox(height: 10),
              ChoiceTiles<HandState>(
                height: 64,
                options: [for (final a in HandState.values) Choice(a, a.label[0].toUpperCase() + a.label.substring(1))],
                selected: session.activity,
                onChanged: (a) => ref.read(sessionProvider.notifier).setActivity(a),
              ),
              const SizedBox(height: 8),
              Text(S.activityHints[session.activity.code], style: TextStyle(fontSize: 16, color: AppColors.textMuted)),
              const SizedBox(height: 14),
              OutlineBigButton(
                icon: Symbols.edit_note_rounded,
                title: session.notes.isEmpty ? S.addNote : '${S.addNote} (${session.notes.length})',
                subtitle: S.addNoteHint,
                onPressed: _addNote,
              ),
              const SizedBox(height: 10),
              OutlineBigButton(
                icon: Symbols.flag_rounded,
                title: session.marks == 0 ? S.markMoment : '${S.markMoment} (${session.marks})',
                subtitle: S.markMomentHint,
                onPressed: () async {
                  await ref.read(sessionProvider.notifier).mark();
                  showMessage(S.momentMarked);
                },
              ),
              const Spacer(),
              GradientButton(label: S.stopSession, icon: Symbols.stop_rounded, danger: true, height: 68, onPressed: _stop),
            ],
          ),
        ),
      ),
    );
  }
}
