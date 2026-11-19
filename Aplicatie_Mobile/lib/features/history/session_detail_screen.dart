import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';
import '../../core/format.dart';
import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/db/models.dart';
import '../../services/export_service.dart';
import '../../state/providers.dart';
import 'charts.dart';

class _Detail {
  const _Detail(this.session, this.samples, this.events);
  final SessionRecord session;
  final List<SampleRecord> samples;
  final List<EventRecord> events;
}

final _detailProvider = FutureProvider.autoDispose.family<_Detail?, int>((ref, id) async {
  final db = ref.watch(databaseProvider);
  final s = await db.session(id);
  if (s == null) return null;
  return _Detail(s, await db.samples(id), await db.events(id));
});

/// Rezumatul unei sesiuni, graficul ei și trimiterea raportului.
class SessionDetailScreen extends ConsumerStatefulWidget {
  const SessionDetailScreen({super.key, required this.sessionId});

  final int sessionId;

  @override
  ConsumerState<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends ConsumerState<SessionDetailScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      showMessage('Nu a mers: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: const Text(S.deleteConfirm, style: TextStyle(fontSize: 19)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text(S.cancel, style: TextStyle(fontSize: 18)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(110, 56), backgroundColor: AppColors.recording),
            onPressed: () => Navigator.pop(c, true),
            child: const Text(S.delete, style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(databaseProvider).deleteSession(id);
    ref.invalidate(historyProvider);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(_detailProvider(widget.sessionId));
    final threshold = ref.watch(settingsProvider.select((s) => s.alertThreshold));

    return Scaffold(
      body: SafeArea(
        child: detail.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (d) {
            if (d == null) return const Center(child: Text('Sesiunea nu mai există.'));
            final s = d.session;
            final duration = s.duration.inSeconds.clamp(1, 1 << 30);
            final alerts = d.events.where((e) => e.kind == EventKind.alert).toList();
            return ListView(
              padding: const EdgeInsets.fromLTRB(AppSizes.pagePadding, 16, AppSizes.pagePadding, 24),
              children: [
                BackHeader(
                  title: S.session,
                  subtitle: '${Fmt.longDate(s.startedAt)} · ${s.activity.label}',
                  trailing: s.simulated ? const _Tag(S.simulatedTag) : null,
                ),
                const SizedBox(height: 14),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: 1.75,
                  children: [
                    _Stat(label: S.durationLabel, value: Fmt.duration(s.duration)),
                    _Stat(label: S.avgFrequency, value: s.avgFrequency == null ? '—' : '${Fmt.hz(s.avgFrequency!)} Hz'),
                    _Stat(label: S.avgIndex, value: '${s.avgIndex}', severity: Severity.fromIndex(s.avgIndex)),
                    _Stat(label: S.maxIndex, value: '${s.maxIndex}', severity: Severity.fromIndex(s.maxIndex)),
                  ],
                ),
                const SizedBox(height: 12),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(S.indexOverTime, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                          Row(
                            children: [
                              Container(
                                width: 11,
                                height: 11,
                                decoration: BoxDecoration(color: AppColors.recording, shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 7),
                              Text(
                                alerts.length == 1 ? '1 alertă' : '${alerts.length} ${S.alerts}',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.recordingText),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SessionChart(
                        values: [for (final x in d.samples) x.index.toDouble()],
                        alertPositions: [for (final a in alerts) a.at.difference(s.startedAt).inSeconds / duration],
                        threshold: threshold,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          for (final f in [0.0, 0.5, 1.0])
                            Text(
                              f == 0 ? '0' : Fmt.duration(Duration(seconds: (duration * f).round())),
                              style: TextStyle(fontSize: 15, color: AppColors.textMuted),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (s.note.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(S.note, style: TextStyle(fontSize: 16, color: AppColors.textMuted)),
                        Text(s.note, style: const TextStyle(fontSize: 18)),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: _busy || d.samples.isEmpty ? null : () => _run(() => ExportService.sharePdf(s, d.samples, d.events)),
                  icon: const Icon(Icons.send_rounded),
                  label: const Text(S.sendPdf),
                ),
                const SizedBox(height: 10),
                OutlineBigButton(
                  icon: Icons.download_rounded,
                  title: S.exportCsv,
                  centered: true,
                  onPressed: _busy || d.samples.isEmpty ? null : () => _run(() => ExportService.shareCsv(s, d.samples)),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  style: TextButton.styleFrom(minimumSize: const Size.fromHeight(56), foregroundColor: AppColors.recording),
                  onPressed: () => _delete(s.id),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text(S.deleteSession, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.severity});

  final String label;
  final String value;
  final Severity? severity;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(fontSize: 16, color: AppColors.textMuted)),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.1)),
              if (severity != null) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: severity!.background, borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      severity!.label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: severity!.foreground),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: const Color(0xFFFFF1C7), borderRadius: BorderRadius.circular(10)),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF5C4300)),
      ),
    );
  }
}
