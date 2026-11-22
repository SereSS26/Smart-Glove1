import 'dart:convert';
import 'dart:ui' show Color;

import '../core/format.dart';
import 'db/models.dart';

/// Forma medicamentului: cum se numește întreg, pe scurt și la plural.
enum MedForm {
  tablet('comprimat', 'cp', 'comprimate'),
  capsule('capsulă', 'caps.', 'capsule'),
  drops('picătură', 'pic.', 'picături'),
  sachet('plic', 'plic', 'plicuri'),
  ml('ml', 'ml', 'ml');

  const MedForm(this.label, this.short, this.plural);
  final String label;
  final String short;
  final String plural;

  /// Picăturile și mililitrii se numără întregi; comprimatele merg și pe jumătate.
  double get step => this == drops || this == ml ? 1 : 0.5;

  static MedForm byName(String? n) => values.firstWhere((f) => f.name == n, orElse: () => tablet);
}

/// Culorile din care alegi pentru un medicament, ca să-l recunoști ușor (aceleași pe ambele teme).
const medColors = <Color>[Color(0xFFE8508A), Color(0xFF3F7DE8), Color(0xFF2F9E77), Color(0xFFE8A33D), Color(0xFF8B5CF6), Color(0xFF0E9AA7)];

/// Ore gata făcute pentru program.
const timePresets = <(String, String)>[('Dimineața', '08:00'), ('Prânz', '14:00'), ('Seara', '20:00'), ('Culcare', '22:00')];

/// „08:00” → (8, 0). Ce nu se poate citi devine 08:00.
(int, int) parseHm(String hm) {
  final m = RegExp(r'^(\d{1,2})[:.](\d{2})$').firstMatch(hm.trim());
  if (m == null) return (8, 0);
  return (int.parse(m.group(1)!).clamp(0, 23), int.parse(m.group(2)!).clamp(0, 59));
}

String hm(int h, int m) => '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

/// Ziua [day] la ora [time].
DateTime atTime(DateTime day, String time) {
  final (h, m) = parseHm(time);
  return DateTime(day.year, day.month, day.day, h, m);
}

DateTime dayOf(DateTime t) => DateTime(t.year, t.month, t.day);

/// Un medicament: ce, cât, când și câte mai ai.
class Medication {
  const Medication({
    this.id,
    this.userId = 'p-ion',
    required this.name,
    this.strength = '',
    this.form = MedForm.tablet,
    this.dose = 1,
    this.times = const ['08:00'],
    this.stock = 30,
    this.packSize = 30,
    this.warnDays = 5,
    this.color = 0,
    this.note = '',
    this.active = true,
    required this.createdAt,
  });

  final int? id;
  final String userId;
  final String name;

  /// Concentrația, ex. „250 mg”.
  final String strength;
  final MedForm form;

  /// Câte unități la o priză (1, ½, 2…).
  final double dose;

  /// Orele prizelor, „HH:mm”, sortate.
  final List<String> times;
  final double stock;
  final int packSize;

  /// Cu câte zile înainte de terminare apare avertismentul.
  final int warnDays;

  /// Indicele din [medColors].
  final int color;
  final String note;
  final bool active;
  final DateTime createdAt;

  String get title => strength.isEmpty ? name : '$name $strength';

  Color get swatch => medColors[color % medColors.length];

  /// „1 cp”, „½ cp”, „2 caps.”
  String get doseShort => '${Fmt.qty(dose)} ${form.short}';

  /// „1 comprimat”, „2 comprimate”, „½ comprimat”
  String get doseLong => '${Fmt.qty(dose)} ${dose > 1 ? form.plural : form.label}';

  /// Consumul pe zi: doza × de câte ori pe zi.
  double get dailyUse => dose * times.length;

  /// Câte zile mai ajunge stocul (null = nu se consumă zilnic).
  double? get daysLeft => dailyUse <= 0 ? null : stock / dailyUse;

  bool get lowStock => daysLeft != null && daysLeft! <= warnDays;

  /// Cât din cutie a rămas, 0–1, pentru bara stocului.
  double get stockFraction => packSize <= 0 ? 0 : (stock / packSize).clamp(0, 1).toDouble();

  Medication copyWith({
    int? id,
    String? name,
    String? strength,
    MedForm? form,
    double? dose,
    List<String>? times,
    double? stock,
    int? packSize,
    int? warnDays,
    int? color,
    String? note,
    bool? active,
  }) => Medication(
    id: id ?? this.id,
    userId: userId,
    name: name ?? this.name,
    strength: strength ?? this.strength,
    form: form ?? this.form,
    dose: dose ?? this.dose,
    times: times ?? this.times,
    stock: stock ?? this.stock,
    packSize: packSize ?? this.packSize,
    warnDays: warnDays ?? this.warnDays,
    color: color ?? this.color,
    note: note ?? this.note,
    active: active ?? this.active,
    createdAt: createdAt,
  );

  Map<String, Object?> toRow() => {
    'id': ?id,
    'user_id': userId,
    'name': name,
    'strength': strength,
    'form': form.name,
    'dose': dose,
    'times': jsonEncode(times),
    'stock': stock,
    'pack_size': packSize,
    'warn_days': warnDays,
    'color': color,
    'shape': 'round',
    'note': note,
    'active': active ? 1 : 0,
    'created_at': createdAt.millisecondsSinceEpoch,
  };

  static Medication fromRow(Map<String, Object?> r) => Medication(
    id: r['id'] as int,
    userId: r['user_id'] as String,
    name: r['name'] as String,
    strength: r['strength'] as String,
    form: MedForm.byName(r['form'] as String?),
    dose: (r['dose'] as num).toDouble(),
    times: sortTimes((jsonDecode(r['times'] as String) as List).cast<String>()),
    stock: (r['stock'] as num).toDouble(),
    packSize: r['pack_size'] as int,
    warnDays: r['warn_days'] as int,
    color: r['color'] as int,
    note: r['note'] as String,
    active: (r['active'] as int) == 1,
    createdAt: DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int),
  );
}

List<String> sortTimes(Iterable<String> times) {
  final list =
      times
          .map((t) {
            final (h, m) = parseHm(t);
            return hm(h, m);
          })
          .toSet()
          .toList()
        ..sort();
  return list;
}

enum IntakeStatus { taken, skipped, snoozed }

/// Ce s-a întâmplat cu o doză programată. La „amânat”, [at] e ora până la care s-a amânat.
class Intake {
  const Intake({required this.medId, required this.scheduledAt, required this.status, this.at});
  final int medId;
  final DateTime scheduledAt;
  final IntakeStatus status;
  final DateTime? at;

  static Intake fromRow(Map<String, Object?> r) => Intake(
    medId: r['med_id'] as int,
    scheduledAt: DateTime.fromMillisecondsSinceEpoch(r['scheduled_at'] as int),
    status: IntakeStatus.values.byName(r['status'] as String),
    at: r['taken_at'] == null ? null : DateTime.fromMillisecondsSinceEpoch(r['taken_at'] as int),
  );
}

enum ReminderKind { test, other }

/// Un reminder care nu e de medicament: testul zilnic sau altceva (exerciții, plimbare…).
class ReminderItem {
  const ReminderItem({
    this.id,
    this.userId = 'p-ion',
    required this.kind,
    required this.title,
    required this.time,
    this.days = const [1, 2, 3, 4, 5, 6, 7],
    this.enabled = true,
  });

  final int? id;
  final String userId;
  final ReminderKind kind;
  final String title;
  final String time;

  /// Zilele săptămânii, 1 = luni … 7 = duminică.
  final List<int> days;
  final bool enabled;

  bool get everyDay => days.length == 7;

  bool onDay(DateTime d) => days.contains(d.weekday);

  /// „În fiecare zi”, „L, Mi, V”
  String get daysLabel {
    if (everyDay) return 'în fiecare zi';
    const short = ['L', 'Ma', 'Mi', 'J', 'V', 'S', 'D'];
    if (days.length == 5 && !days.contains(6) && !days.contains(7)) return 'de luni până vineri';
    return ([...days]..sort()).map((d) => short[d - 1]).join(', ');
  }

  ReminderItem copyWith({String? title, String? time, List<int>? days, bool? enabled}) => ReminderItem(
    id: id,
    userId: userId,
    kind: kind,
    title: title ?? this.title,
    time: time ?? this.time,
    days: days ?? this.days,
    enabled: enabled ?? this.enabled,
  );

  Map<String, Object?> toRow() => {
    'id': ?id,
    'user_id': userId,
    'kind': kind.name,
    'title': title,
    'time': time,
    'days': jsonEncode(days),
    'enabled': enabled ? 1 : 0,
  };

  static ReminderItem fromRow(Map<String, Object?> r) => ReminderItem(
    id: r['id'] as int,
    userId: r['user_id'] as String,
    kind: ReminderKind.values.byName(r['kind'] as String),
    title: r['title'] as String,
    time: r['time'] as String,
    days: (jsonDecode(r['days'] as String) as List).cast<int>(),
    enabled: (r['enabled'] as int) == 1,
  );
}

/// Starea unui rând din „Azi”.
enum PlanStatus { done, skipped, due, snoozed, upcoming, missed, passed }

/// Un rând din „Azi”: o doză sau un reminder, la ora lui.
class PlanEntry {
  const PlanEntry({required this.at, required this.status, this.med, this.reminder, this.time = '', this.doneAt});
  final DateTime at;
  final PlanStatus status;
  final Medication? med;
  final ReminderItem? reminder;

  /// Ora din program („14:00”), pentru doze.
  final String time;

  /// Când s-a luat doza sau până când s-a amânat.
  final DateTime? doneAt;

  bool get isDose => med != null;
  bool get isTest => reminder?.kind == ReminderKind.test;

  /// Se numără la „X din Y făcute” (reminderele simple nu au bifă).
  bool get counts => isDose || isTest;
  bool get finished => status == PlanStatus.done || status == PlanStatus.skipped;
}

/// Cât înainte de oră apare „Am luat” și după cât timp o doză e considerată ratată.
const dueBefore = Duration(minutes: 30);
const missedAfter = Duration(minutes: 60);

PlanStatus _timeStatus(DateTime at, DateTime now) {
  if (now.isBefore(at.subtract(dueBefore))) return PlanStatus.upcoming;
  if (!now.isAfter(at.add(missedAfter))) return PlanStatus.due;
  return PlanStatus.missed;
}

/// Planul unei zile: dozele fiecărui medicament activ și reminderele active, în ordinea orelor.
List<PlanEntry> dayPlan({
  required List<Medication> meds,
  required List<ReminderItem> reminders,
  required List<Intake> intakes,
  required bool testDone,
  required DateTime day,
  required DateTime now,
}) {
  final byKey = {for (final i in intakes) '${i.medId}@${i.scheduledAt.millisecondsSinceEpoch}': i};
  final out = <PlanEntry>[];
  for (final m in meds.where((m) => m.active)) {
    for (final t in m.times) {
      final at = atTime(day, t);
      final i = byKey['${m.id}@${at.millisecondsSinceEpoch}'];
      final PlanStatus status;
      DateTime? doneAt = i?.at;
      switch (i?.status) {
        case IntakeStatus.taken:
          status = PlanStatus.done;
        case IntakeStatus.skipped:
          status = PlanStatus.skipped;
        case IntakeStatus.snoozed:
          status = i!.at != null && now.isBefore(i.at!) ? PlanStatus.snoozed : PlanStatus.due;
        case null:
          status = _timeStatus(at, now);
          doneAt = null;
      }
      out.add(PlanEntry(at: at, status: status, med: m, time: t, doneAt: doneAt));
    }
  }
  for (final r in reminders.where((r) => r.enabled && r.onDay(day))) {
    final at = atTime(day, r.time);
    final status = switch (r.kind) {
      ReminderKind.test => testDone ? PlanStatus.done : _timeStatus(at, now),
      ReminderKind.other => now.isAfter(at) ? PlanStatus.passed : PlanStatus.upcoming,
    };
    out.add(PlanEntry(at: at, status: status, reminder: r, time: r.time));
  }
  out.sort((a, b) => a.at.compareTo(b.at));
  return out;
}

/// Aderența: din dozele programate deja trecute în [from, to), câte au fost luate, în procente.
int? adherence({
  required List<Medication> meds,
  required List<Intake> intakes,
  required DateTime from,
  required DateTime to,
  required DateTime now,
}) {
  final taken = {
    for (final i in intakes)
      if (i.status == IntakeStatus.taken) '${i.medId}@${i.scheduledAt.millisecondsSinceEpoch}',
  };
  final end = to.isBefore(now) ? to : now;
  var scheduled = 0, ok = 0;
  for (final m in meds.where((m) => m.active)) {
    final since = dayOf(m.createdAt);
    for (var d = dayOf(from); d.isBefore(end); d = DateTime(d.year, d.month, d.day + 1)) {
      if (d.isBefore(since)) continue;
      for (final t in m.times) {
        final at = atTime(d, t);
        if (at.isBefore(from) || at.isAfter(end)) continue;
        scheduled++;
        if (taken.contains('${m.id}@${at.millisecondsSinceEpoch}')) ok++;
      }
    }
  }
  return scheduled == 0 ? null : (100 * ok / scheduled).round();
}

/// Observație din date: tremorul în cele 2 ore după o doză față de restul timpului.
String? afterDoseInsight(List<SampleRecord> samples, List<Intake> intakes) {
  final times = [
    for (final i in intakes)
      if (i.status == IntakeStatus.taken && i.at != null) i.at!.millisecondsSinceEpoch,
  ]..sort();
  if (times.isEmpty) return null;
  const window = 2 * 3600 * 1000;
  var sa = 0.0, na = 0, so = 0.0, no = 0;
  for (final s in samples) {
    final t = s.at.millisecondsSinceEpoch;
    // Cea mai recentă doză luată înainte de eșantion (căutare binară).
    var lo = 0, hi = times.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (times[mid] <= t) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    final after = lo > 0 && t - times[lo - 1] <= window;
    if (after) {
      sa += s.index;
      na++;
    } else {
      so += s.index;
      no++;
    }
  }
  if (na < 60 || no < 60 || so == 0) return null;
  final d = ((sa / na - so / no) / (so / no) * 100).round();
  if (d.abs() < 5) return 'În cele 2 ore după o doză, tremorul e cam la fel ca în rest.';
  return d < 0
      ? 'În cele 2 ore după o doză, indicele e în medie cu ${-d} % mai mic.'
      : 'În cele 2 ore după o doză, indicele e în medie cu $d % mai mare.';
}

/// Ce notificare programată trebuie să existe. [weekday] = null înseamnă zilnic; [once] = o singură dată.
class PlannedNote {
  const PlannedNote({
    required this.id,
    required this.channel,
    required this.title,
    required this.body,
    required this.payload,
    this.time,
    this.weekday,
    this.once,
    this.doseActions = false,
  });
  final int id;
  final NoteChannel channel;
  final String title;
  final String body;
  final String payload;
  final String? time;
  final int? weekday;
  final DateTime? once;
  final bool doseActions;
}

enum NoteChannel { medications, tests, stock, other }

/// Ce poate trimite aplicația: doze, teste, stoc mic.
class ReminderPrefs {
  const ReminderPrefs({this.meds = true, this.tests = true, this.stock = true});
  final bool meds;
  final bool tests;
  final bool stock;

  ReminderPrefs copyWith({bool? meds, bool? tests, bool? stock}) =>
      ReminderPrefs(meds: meds ?? this.meds, tests: tests ?? this.tests, stock: stock ?? this.stock);
}

/// Încărcătura unei notificări de doză: tot ce trebuie ca „Am luat” și „Amână” să meargă cu aplicația închisă.
String dosePayload(Medication m, String time, String title, String body) =>
    jsonEncode({'t': 'dose', 'm': m.id, 'h': time, 'title': title, 'body': body});

/// Notificările care trebuie programate acum, din medicamente, remindere și preferințe.
List<PlannedNote> plannedNotes({
  required List<Medication> meds,
  required List<ReminderItem> reminders,
  required ReminderPrefs prefs,
  required DateTime now,
}) {
  final out = <PlannedNote>[];
  for (final m in meds.where((m) => m.active && m.id != null)) {
    if (prefs.meds) {
      for (var i = 0; i < m.times.length && i < 10; i++) {
        final title = 'E ora pentru ${m.title}';
        final body = '${m.doseLong[0].toUpperCase()}${m.doseLong.substring(1)}${m.note.isEmpty ? '' : ' · ${m.note}'}';
        out.add(
          PlannedNote(
            id: 1000 + m.id! * 10 + i,
            channel: NoteChannel.medications,
            title: title,
            body: body,
            payload: dosePayload(m, m.times[i], title, body),
            time: m.times[i],
            doseActions: true,
          ),
        );
      }
    }
    if (prefs.stock && m.lowStock) {
      final today10 = DateTime(now.year, now.month, now.day, 10);
      final days = m.daysLeft!.floor();
      out.add(
        PlannedNote(
          id: 30000 + m.id!,
          channel: NoteChannel.stock,
          title: 'Stoc mic: ${m.title}',
          body: days <= 0
              ? 'S-a terminat ${m.name}. Cumpără o cutie.'
              : 'Mai ai ${m.name} pentru ${days == 1 ? 'o zi' : '$days zile'}. Cumpără o cutie.',
          payload: jsonEncode({'t': 'stock', 'm': m.id}),
          once: now.isBefore(today10) ? today10 : today10.add(const Duration(days: 1)),
        ),
      );
    }
  }
  for (final r in reminders.where((r) => r.enabled && r.id != null)) {
    final test = r.kind == ReminderKind.test;
    if (test && !prefs.tests) continue;
    final base = PlannedNote(
      id: 0,
      channel: test ? NoteChannel.tests : NoteChannel.other,
      title: test ? 'E timpul pentru testul de azi' : r.title,
      body: test ? 'Evaluarea completă durează cam 3 minute.' : 'Reminder la ${r.time}',
      payload: jsonEncode({'t': test ? 'test' : 'other', 'r': r.id}),
    );
    final days = r.everyDay ? [null] : r.days;
    for (final d in days) {
      out.add(
        PlannedNote(
          id: 20000 + r.id! * 10 + (d ?? 0),
          channel: base.channel,
          title: base.title,
          body: base.body,
          payload: base.payload,
          time: r.time,
          weekday: d,
        ),
      );
    }
  }
  return out;
}
