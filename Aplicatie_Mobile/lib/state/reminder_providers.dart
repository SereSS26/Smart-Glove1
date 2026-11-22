import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/models.dart';
import '../data/medication_repository.dart';
import '../data/medications.dart';
import '../services/share_inbox.dart';
import 'providers.dart';

/// „Trimite către Mănușa”: text sau poze din alte aplicații.
final shareInboxProvider = Provider<ShareInbox>((_) => ShareInbox());

final medicationRepositoryProvider = Provider<MedicationRepository>((ref) => MedicationRepository(ref.watch(databaseProvider).raw));

/// Crește la orice schimbare de medicamente, doze sau remindere; cine afișează astfel de date îl urmărește.
class MedsVersion extends Notifier<int> {
  @override
  int build() => 0;
  void bump() => state++;
}

final medsVersionProvider = NotifierProvider<MedsVersion, int>(MedsVersion.new);

/// Ce trimite aplicația: doze, teste, stoc mic.
class ReminderPrefsNotifier extends Notifier<ReminderPrefs> {
  @override
  ReminderPrefs build() {
    final p = ref.watch(prefsProvider);
    return ReminderPrefs(meds: p.getBool('rem.meds') ?? true, tests: p.getBool('rem.tests') ?? true, stock: p.getBool('rem.stock') ?? true);
  }

  Future<void> update(ReminderPrefs Function(ReminderPrefs p) change) async {
    state = change(state);
    final p = ref.read(prefsProvider);
    await p.setBool('rem.meds', state.meds);
    await p.setBool('rem.tests', state.tests);
    await p.setBool('rem.stock', state.stock);
    await ref.read(remindersActionsProvider).reschedule();
  }
}

final reminderPrefsProvider = NotifierProvider<ReminderPrefsNotifier, ReminderPrefs>(ReminderPrefsNotifier.new);

/// Datele filei Remindere pentru ziua de azi.
class RemindersData {
  const RemindersData({required this.day, required this.meds, required this.reminders, required this.intakes, required this.testDone});
  final DateTime day;
  final List<Medication> meds;
  final List<ReminderItem> reminders;
  final List<Intake> intakes;
  final bool testDone;

  List<PlanEntry> plan(DateTime now) => dayPlan(meds: meds, reminders: reminders, intakes: intakes, testDone: testDone, day: day, now: now);

  List<Medication> get lowStock => meds.where((m) => m.lowStock).toList();
}

final remindersDataProvider = FutureProvider.autoDispose<RemindersData>((ref) async {
  ref.watch(medsVersionProvider);
  final repo = ref.watch(medicationRepositoryProvider);
  final db = ref.watch(databaseProvider);
  final demo = ref.watch(settingsProvider.select((s) => s.demoMode));
  final day = dayOf(DateTime.now());
  final next = DateTime(day.year, day.month, day.day + 1);
  final sessions = await db.sessions(simulated: demo, since: day);
  return RemindersData(
    day: day,
    meds: await repo.medications(),
    reminders: await repo.reminders(),
    intakes: await repo.intakesBetween(day, next),
    testDone: sessions.any((s) => s.kind == SessionKind.assessment),
  );
});

/// Acțiunile din Remindere: fiecare scrie în bază, reîmprospătează ecranele și reprogramează notificările.
class RemindersActions {
  RemindersActions(this._ref);
  final Ref _ref;

  MedicationRepository get _repo => _ref.read(medicationRepositoryProvider);

  void _changed() => _ref.read(medsVersionProvider.notifier).bump();

  Future<void> reschedule() async {
    final service = _ref.read(notificationsProvider);
    if (!service.ready) return; // fără notificări (ex. în teste) nu e nimic de programat
    final repo = _repo;
    final notes = plannedNotes(
      meds: await repo.medications(),
      reminders: await repo.reminders(),
      prefs: _ref.read(reminderPrefsProvider),
      now: DateTime.now(),
    );
    await service.reschedule(notes);
  }

  Future<void> _after() async {
    _changed();
    await reschedule();
  }

  Future<void> markTaken(Medication m, DateTime scheduledAt) async {
    await _repo.markTaken(m.id!, scheduledAt);
    final i = m.times.indexOf(hm(scheduledAt.hour, scheduledAt.minute));
    if (i >= 0) await _ref.read(notificationsProvider).cancelDose(m.id!, i);
    await _after();
  }

  Future<void> undo(Medication m, DateTime scheduledAt) async {
    await _repo.undo(m.id!, scheduledAt);
    await _after();
  }

  Future<void> snooze(Medication m, DateTime scheduledAt) async {
    final until = DateTime.now().add(const Duration(minutes: 10));
    await _repo.snooze(m.id!, scheduledAt, until);
    final title = 'E ora pentru ${m.title}';
    final body = '${m.doseLong[0].toUpperCase()}${m.doseLong.substring(1)}';
    await _ref.read(notificationsProvider).snoozeDose({
      't': 'dose',
      'm': m.id,
      'h': hm(scheduledAt.hour, scheduledAt.minute),
      'title': title,
      'body': body,
    });
    _changed();
  }

  Future<void> skip(Medication m, DateTime scheduledAt) async {
    await _repo.skip(m.id!, scheduledAt);
    _changed();
  }

  Future<void> addStock(Medication m, double qty) async {
    await _repo.addStock(m.id!, qty);
    await _after();
  }

  Future<Medication> save(Medication m) async {
    final saved = await _repo.save(m);
    await _after();
    return saved;
  }

  Future<List<Medication>> saveAll(List<Medication> meds) async {
    final saved = await _repo.saveAll(meds);
    await _after();
    return saved;
  }

  Future<void> delete(Medication m) async {
    await _repo.delete(m.id!);
    await _after();
  }

  Future<void> saveReminder(ReminderItem r) async {
    await _repo.saveReminder(r);
    await _after();
  }

  Future<void> deleteReminder(ReminderItem r) async {
    await _repo.deleteReminder(r.id!);
    await _after();
  }

  /// Se cheamă după ce o notificare a schimbat ceva din fundal.
  void refresh() => _changed();
}

final remindersActionsProvider = Provider<RemindersActions>(RemindersActions.new);
