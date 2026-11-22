import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../app.dart';
import '../../core/format.dart';
import '../../core/strings.dart';
import '../../core/tests.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/medications.dart';
import '../../state/reminder_providers.dart';
import '../../ui/ui.dart';
import '../tests/test_runner_screen.dart';
import 'add_sheet.dart';
import 'medication_form.dart';
import 'reminder_edit_screen.dart';
import '../../services/feedback.dart';

/// Fila Remindere: dozele și testele de azi, medicamentele cu stocul lor și celelalte remindere.
class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen> with WidgetsBindingObserver {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Stările („e ora acum”, „nebifat”) depind de ceas: redesenăm la fiecare minut.
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tick?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // O doză bifată din notificare, cu aplicația în fundal, trebuie să apară și aici.
    if (state == AppLifecycleState.resumed) ref.read(remindersActionsProvider).refresh();
  }

  void _add() => showAddSheet(context);

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(remindersDataProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(AppSizes.pagePadding, 14, AppSizes.pagePadding, 24),
      children: [
        Row(
          children: [
            Expanded(child: Text(S.tabReminders, style: Theme.of(context).textTheme.headlineMedium)),
            FilledButton.tonalIcon(
              onPressed: _add,
              style: FilledButton.styleFrom(
                minimumSize: const Size(48, 48),
                backgroundColor: AppColors.accentSoft,
                foregroundColor: AppColors.accentDark,
              ),
              icon: const Icon(Symbols.add_rounded),
              label: const Text('Adaugă', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...async.when(
          data: (d) => _content(d),
          loading: () => [
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
          error: (e, _) => [AppCard(child: Text('Nu am putut citi reminderele: $e'))],
        ),
      ],
    );
  }

  List<Widget> _content(RemindersData d) {
    final now = DateTime.now();
    if (dayOf(now) != d.day) {
      // A trecut miezul nopții: citim ziua nouă.
      WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(remindersActionsProvider).refresh());
    }
    if (d.meds.isEmpty && d.reminders.isEmpty) {
      return [
        AppCard(
          child: EmptyState(
            icon: Symbols.medication_rounded,
            text: 'Adaugă medicamentele tale: îți amintim de fiecare doză și îți spunem când se termină cutia.',
            actionLabel: 'Adaugă un medicament',
            onAction: _add,
          ),
        ),
      ];
    }
    final plan = d.plan(now);
    final counted = plan.where((e) => e.counts).toList();
    final done = counted.where((e) => e.finished).length;
    return [
      for (final m in d.lowStock) ...[_LowStockBanner(med: m, onBuy: () => _buy(m)), const SizedBox(height: 10)],
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 8),
        child: SectionLabel(counted.isEmpty ? 'Azi' : 'Azi · $done din ${counted.length} făcute'),
      ),
      AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: plan.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text('Nimic programat azi.', style: TextStyle(fontSize: 17, color: AppColors.textMuted)),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < plan.length; i++) ...[
                    if (i > 0) Divider(height: 1, color: AppColors.divider),
                    _PlanRow(
                      entry: plan[i],
                      onTaken: () => _taken(plan[i]),
                      onSnooze: () => _snooze(plan[i]),
                      onSkip: () => ref.read(remindersActionsProvider).skip(plan[i].med!, plan[i].at),
                      onUndo: () => _confirmUndo(plan[i]),
                      onTest: _startTest,
                    ),
                  ],
                ],
              ),
      ),
      const Padding(padding: EdgeInsets.fromLTRB(4, 20, 4, 8), child: SectionLabel('Medicamentele mele')),
      if (d.meds.isEmpty)
        AppCard(
          child: EmptyState(
            icon: Symbols.medication_rounded,
            text: 'Niciun medicament încă.',
            actionLabel: 'Adaugă un medicament',
            onAction: _add,
          ),
        ),
      for (final m in d.meds) ...[
        _MedCard(
          med: m,
          onOpen: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => MedicationEditScreen(medication: m))),
          onBuy: () => _buy(m),
        ),
        const SizedBox(height: 10),
      ],
      const Padding(padding: EdgeInsets.fromLTRB(4, 10, 4, 8), child: SectionLabel('Alte remindere')),
      SettingsGroup(
        children: [
          for (final r in d.reminders) _ReminderRow(reminder: r),
          NavRow(
            icon: Symbols.add_alert_rounded,
            title: d.reminders.isEmpty ? 'Pune un reminder pentru testul zilnic' : 'Adaugă un reminder',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ReminderEditScreen(kind: d.reminders.isEmpty ? ReminderKind.test : ReminderKind.other),
              ),
            ),
          ),
        ],
      ),
    ];
  }

  Future<void> _taken(PlanEntry e) async {
    Haptics.medium();
    final m = e.med!;
    await ref.read(remindersActionsProvider).markTaken(m, e.at);
    showMessage(
      'Am notat: ${m.title}, ${Fmt.time(DateTime.now())}.',
      actionLabel: 'Anulează',
      onAction: () => ref.read(remindersActionsProvider).undo(m, e.at),
    );
  }

  Future<void> _snooze(PlanEntry e) async {
    await ref.read(remindersActionsProvider).snooze(e.med!, e.at);
    showMessage('Îți amintim din nou peste 10 minute.');
  }

  Future<void> _confirmUndo(PlanEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Anulezi bifa?'),
        content: Text('${e.med!.title} de la ${e.time} redevine nebifat, iar doza se pune înapoi în stoc.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Nu')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Da, anulează')),
        ],
      ),
    );
    if (ok == true) await ref.read(remindersActionsProvider).undo(e.med!, e.at);
  }

  void _startTest() =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TestRunnerScreen(tests: TestKind.assessment)));

  Future<void> _buy(Medication m) => showBuySheet(context, ref, m);
}

/// „Am cumpărat”: câte unități intră în stoc (implicit o cutie).
Future<void> showBuySheet(BuildContext context, WidgetRef ref, Medication m) {
  var qty = m.packSize.toDouble();
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSizes.pagePadding, 0, AppSizes.pagePadding, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Ai cumpărat ${m.title}', style: Theme.of(c).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('Acum ai ${Fmt.stock(m.stock)} ${m.form.plural}.', style: TextStyle(fontSize: 16, color: AppColors.textMuted)),
              const SizedBox(height: 16),
              Center(
                child: StepperField(
                  value: Fmt.stock(qty),
                  valueWidth: 80,
                  minusLabel: 'Mai puține',
                  plusLabel: 'Mai multe',
                  onMinus: qty > 1 ? () => set(() => qty -= 1) : null,
                  onPlus: () => set(() => qty += 1),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final n in [1, 2, 3])
                    ToggleChip(
                      label: n == 1 ? 'o cutie (${m.packSize})' : '$n cutii (${m.packSize * n})',
                      selected: qty == m.packSize * n,
                      onTap: () => set(() => qty = (m.packSize * n).toDouble()),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              GradientButton(
                label: 'Adaugă ${Fmt.stock(qty)} în stoc',
                icon: Symbols.add_shopping_cart_rounded,
                onPressed: () async {
                  Navigator.pop(c);
                  await ref.read(remindersActionsProvider).addStock(m, qty);
                  showMessage('Stocul de ${m.name} a crescut la ${Fmt.stock(m.stock + qty)}.');
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _LowStockBanner extends StatelessWidget {
  const _LowStockBanner({required this.med, required this.onBuy});

  final Medication med;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final days = med.daysLeft!.floor();
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.warningBorder),
      ),
      child: Row(
        children: [
          Icon(Symbols.inventory_2_rounded, color: AppColors.warningFg, fill: 1),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              days <= 0 ? 'S-a terminat ${med.title}.' : 'Mai ai ${med.title} pentru ${days == 1 ? 'o zi' : '$days zile'}.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.warningFg),
            ),
          ),
          TextButton(
            onPressed: onBuy,
            child: Text(
              'Am cumpărat',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.warningFg),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({
    required this.entry,
    required this.onTaken,
    required this.onSnooze,
    required this.onSkip,
    required this.onUndo,
    required this.onTest,
  });

  final PlanEntry entry;
  final VoidCallback onTaken;
  final VoidCallback onSnooze;
  final VoidCallback onSkip;
  final VoidCallback onUndo;
  final VoidCallback onTest;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final m = e.med;
    final (IconData icon, Color color, bool fill) = switch (e.status) {
      PlanStatus.done => (Symbols.check_circle_rounded, AppColors.ok, true),
      PlanStatus.skipped => (Symbols.do_not_disturb_on_rounded, AppColors.textMuted, false),
      PlanStatus.due => (Symbols.radio_button_checked_rounded, AppColors.accent, true),
      PlanStatus.snoozed => (Symbols.snooze_rounded, AppColors.warningFg, false),
      PlanStatus.upcoming => (Symbols.radio_button_unchecked_rounded, AppColors.mutedDot, false),
      PlanStatus.missed => (Symbols.error_rounded, AppColors.bad, true),
      PlanStatus.passed => (Symbols.check_rounded, AppColors.textMuted, false),
    };
    final title = m != null ? '${m.title} · ${m.doseShort}' : e.reminder!.title;
    final sub = switch (e.status) {
      PlanStatus.done when m != null => 'luat la ${Fmt.time(e.doneAt ?? e.at)}',
      PlanStatus.done => 'făcut azi',
      PlanStatus.skipped => 'sărit',
      PlanStatus.due when m != null => 'e ora acum',
      PlanStatus.due => 'e timpul pentru test',
      PlanStatus.snoozed => 'amânat până la ${Fmt.time(e.doneAt!)}',
      PlanStatus.missed when m != null => 'nebifat',
      PlanStatus.missed => 'nefăcut încă',
      _ => m?.note.isNotEmpty == true ? m!.note : null,
    };
    final muted = e.finished || e.status == PlanStatus.passed;
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 62,
            child: Text(
              e.time,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                fontFeatures: tabular,
                color: muted ? AppColors.textMuted : AppColors.text,
              ),
            ),
          ),
          Icon(icon, size: 24, color: color, fill: fill ? 1 : 0),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (m != null) ...[
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: m.swatch, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                    ] else
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(
                          e.isTest ? Symbols.ecg_heart_rounded : Symbols.notifications_rounded,
                          size: 18,
                          color: AppColors.textMuted,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: muted ? AppColors.textMuted : AppColors.text,
                          decoration: e.status == PlanStatus.skipped ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                  ],
                ),
                if (sub != null)
                  Text(
                    sub,
                    style: TextStyle(
                      fontSize: 15,
                      color: e.status == PlanStatus.missed
                          ? AppColors.bad
                          : (e.status == PlanStatus.due ? AppColors.accentDark : AppColors.textMuted),
                      fontWeight: e.status == PlanStatus.due ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    final actionable = e.status == PlanStatus.due || e.status == PlanStatus.snoozed || e.status == PlanStatus.missed;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (m != null && e.status == PlanStatus.done)
          Semantics(
            hint: 'apasă ca să anulezi bifa',
            child: InkWell(onTap: onUndo, child: row),
          )
        else
          row,
        if (actionable && m != null)
          Padding(
            padding: const EdgeInsets.only(left: 62, bottom: 12),
            child: e.status == PlanStatus.missed
                ? Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      OutlinedButton(
                        onPressed: onTaken,
                        style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
                        child: const Text('Am luat totuși'),
                      ),
                      TextButton(
                        onPressed: onSkip,
                        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                        child: const Text('Sar peste'),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GradientButton(label: 'Am luat', icon: Symbols.check_rounded, height: 56, onPressed: onTaken),
                      if (e.status == PlanStatus.due)
                        TextButton(
                          onPressed: onSnooze,
                          style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                          child: const Text('Amână 10 min'),
                        ),
                    ],
                  ),
          ),
        if (actionable && e.isTest)
          Padding(
            padding: const EdgeInsets.only(left: 62, bottom: 12),
            child: GradientButton(label: 'Fă testul', icon: Symbols.play_arrow_rounded, height: 56, onPressed: onTest),
          ),
      ],
    );
  }
}

class _MedCard extends StatelessWidget {
  const _MedCard({required this.med, required this.onOpen, required this.onBuy});

  final Medication med;
  final VoidCallback onOpen;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    final m = med;
    final days = m.daysLeft;
    final left = days == null ? '' : ' · ajunge ${days.floor() == 1 ? 'o zi' : '${days.floor()} zile'}';
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onOpen,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSizes.radius)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 8, 8),
              child: Row(
                children: [
                  PillAvatar(color: m.swatch),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(m.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                        Text('${m.doseShort} · ${m.times.join(', ')}', style: TextStyle(fontSize: 15, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  Icon(Symbols.chevron_right_rounded, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
            child: StockBar(fraction: m.stockFraction, low: m.lowStock),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 6, 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${Fmt.stock(m.stock)} buc.$left',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: m.lowStock ? AppColors.bad : AppColors.textMuted),
                  ),
                ),
                TextButton.icon(
                  onPressed: onBuy,
                  style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                  icon: const Icon(Symbols.add_shopping_cart_rounded, size: 20),
                  label: const Text('Am cumpărat'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderRow extends ConsumerWidget {
  const _ReminderRow({required this.reminder});

  final ReminderItem reminder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = reminder;
    return MergeSemantics(
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ReminderEditScreen(reminder: r))),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 10, 8),
            child: Row(
              children: [
                Icon(r.kind == ReminderKind.test ? Symbols.ecg_heart_rounded : Symbols.notifications_rounded, color: AppColors.accentDark),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                      Text('${r.time} · ${r.daysLabel}', style: TextStyle(fontSize: 15, color: AppColors.textMuted)),
                    ],
                  ),
                ),
                Switch(
                  value: r.enabled,
                  onChanged: (v) => ref.read(remindersActionsProvider).saveReminder(r.copyWith(enabled: v)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
