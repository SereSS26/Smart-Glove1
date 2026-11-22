import 'dart:async';
import 'dart:convert';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/medication_repository.dart';
import '../data/medications.dart';

/// Butoanele din notificarea de doză.
abstract final class NoteAction {
  static const taken = 'taken';
  static const snooze = 'snooze';
}

const snoozeFor = Duration(minutes: 10);

/// Notificările locale: alerte de tremor, doze, teste și stoc. Nimic nu pleacă din telefon.
class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool _tzReady = false;
  final _responses = StreamController<NotificationResponse>.broadcast();

  /// Apăsări pe notificări cât timp aplicația e deschisă (inclusiv pe butoane).
  Stream<NotificationResponse> get responses => _responses.stream;

  bool get ready => _ready;

  static const _alerts = AndroidNotificationDetails(
    'alerte_tremor',
    'Alerte tremor',
    channelDescription: 'Când tremorul trece de pragul ales',
    importance: Importance.high,
    priority: Priority.high,
  );

  static AndroidNotificationDetails _android(NoteChannel c, {bool actions = false}) => switch (c) {
    NoteChannel.medications => AndroidNotificationDetails(
      'medicamente',
      'Medicamente',
      channelDescription: 'Ora fiecărei doze',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      actions: actions
          ? const [
              AndroidNotificationAction(NoteAction.taken, 'Am luat', cancelNotification: true),
              AndroidNotificationAction(NoteAction.snooze, 'Amână 10 min', cancelNotification: true),
            ]
          : null,
    ),
    NoteChannel.tests => const AndroidNotificationDetails(
      'teste',
      'Teste',
      channelDescription: 'Reminderul pentru testul zilnic',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
    ),
    NoteChannel.stock => const AndroidNotificationDetails(
      'stoc',
      'Stoc medicamente',
      channelDescription: 'Când un medicament e pe terminate',
      importance: Importance.defaultImportance,
    ),
    NoteChannel.other => const AndroidNotificationDetails(
      'remindere',
      'Alte remindere',
      channelDescription: 'Remindere puse de tine',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
    ),
  };

  static DarwinNotificationDetails _darwin(NoteChannel c) =>
      DarwinNotificationDetails(categoryIdentifier: c == NoteChannel.medications ? 'dose' : null);

  Future<void> init() async {
    try {
      await _plugin.initialize(
        settings: InitializationSettings(
          android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            notificationCategories: [
              DarwinNotificationCategory(
                'dose',
                actions: [
                  DarwinNotificationAction.plain(NoteAction.taken, 'Am luat'),
                  DarwinNotificationAction.plain(NoteAction.snooze, 'Amână 10 min'),
                ],
              ),
            ],
          ),
        ),
        onDidReceiveNotificationResponse: _responses.add,
        onDidReceiveBackgroundNotificationResponse: onBackgroundNotification,
      );
      _ready = true;
      await _initTimezone();
    } catch (_) {
      // Fără notificări (ex. în teste); alertele rămân vizibile în aplicație.
    }
  }

  Future<void> _initTimezone() async {
    if (_tzReady) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Europe/Bucharest'));
    }
    _tzReady = true;
  }

  /// Notificarea care a deschis aplicația (dacă a fost una).
  Future<NotificationResponse?> launchResponse() async {
    if (!_ready) return null;
    final d = await _plugin.getNotificationAppLaunchDetails();
    return d?.didNotificationLaunchApp == true ? d!.notificationResponse : null;
  }

  /// Pe Android 13+ trebuie cerută permisiunea; o cerem la prima pornire.
  Future<void> requestPermission() async {
    if (!_ready) return;
    await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    await _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, sound: true);
  }

  AndroidFlutterLocalNotificationsPlugin? get _androidPlugin =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  /// Poate suna la minut? (Android 12+ cere „Alarme și mementouri”.)
  Future<bool> canScheduleExact() async {
    if (!_ready) return true;
    return await _androidPlugin?.canScheduleExactNotifications() ?? true;
  }

  Future<void> requestExact() async {
    if (!_ready) return;
    await _androidPlugin?.requestExactAlarmsPermission();
  }

  Future<void> showAlert({required int index, required int threshold}) async {
    if (!_ready) return;
    await _plugin.show(
      id: 1,
      title: 'Tremor peste prag',
      body: 'Indicele de tremor a ajuns la $index (pragul tău: $threshold).',
      notificationDetails: const NotificationDetails(android: _alerts, iOS: DarwinNotificationDetails()),
    );
  }

  /// Înlocuiește toate notificările programate cu [notes].
  Future<void> reschedule(List<PlannedNote> notes) async {
    if (!_ready) return;
    await _initTimezone();
    final pending = await _plugin.pendingNotificationRequests();
    final keep = {for (final n in notes) n.id};
    for (final r in pending) {
      // Amânările (40000+) rămân până sună.
      if (r.id >= 1000 && r.id < 40000 && !keep.contains(r.id)) await _plugin.cancel(id: r.id);
    }
    final mode = await canScheduleExact() ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle;
    for (final n in notes) {
      await _schedule(n, mode);
    }
  }

  Future<void> _schedule(PlannedNote n, AndroidScheduleMode mode) async {
    final now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime when;
    DateTimeComponents? repeat;
    if (n.once != null) {
      when = tz.TZDateTime.from(n.once!, tz.local);
      if (!when.isAfter(now)) return;
    } else {
      final (h, m) = parseHm(n.time!);
      when = tz.TZDateTime(tz.local, now.year, now.month, now.day, h, m);
      if (n.weekday != null) {
        while (when.weekday != n.weekday || !when.isAfter(now)) {
          when = tz.TZDateTime(tz.local, when.year, when.month, when.day + 1, h, m);
        }
        repeat = DateTimeComponents.dayOfWeekAndTime;
      } else {
        if (!when.isAfter(now)) when = tz.TZDateTime(tz.local, now.year, now.month, now.day + 1, h, m);
        repeat = DateTimeComponents.time;
      }
    }
    await _plugin.zonedSchedule(
      id: n.id,
      title: n.title,
      body: n.body,
      scheduledDate: when,
      notificationDetails: NotificationDetails(
        android: _android(n.channel, actions: n.doseActions),
        iOS: _darwin(n.channel),
      ),
      androidScheduleMode: mode,
      matchDateTimeComponents: repeat,
      payload: n.payload,
    );
  }

  /// O singură notificare programată, în afara reminderelor (ex. rezumatul săptămânal al medicului, id 50000+).
  Future<void> scheduleOne(PlannedNote n) async {
    if (!_ready) return;
    await _initTimezone();
    final mode = await canScheduleExact() ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle;
    await _schedule(n, mode);
  }

  Future<void> cancelId(int id) async {
    if (!_ready) return;
    await _plugin.cancel(id: id);
  }

  /// Amână o doză: aceeași notificare, peste 10 minute, o singură dată.
  Future<void> snoozeDose(Map<String, dynamic> payload) async {
    if (!_ready) return;
    await _initTimezone();
    final medId = payload['m'] as int;
    final (h, _) = parseHm(payload['h'] as String);
    final mode = await canScheduleExact() ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle;
    await _plugin.zonedSchedule(
      id: 40000 + medId * 24 + h,
      title: payload['title'] as String?,
      body: payload['body'] as String?,
      scheduledDate: tz.TZDateTime.now(tz.local).add(snoozeFor),
      notificationDetails: NotificationDetails(
        android: _android(NoteChannel.medications, actions: true),
        iOS: _darwin(NoteChannel.medications),
      ),
      androidScheduleMode: mode,
      payload: jsonEncode(payload),
    );
  }

  /// Scoate notificarea de doză din bară (după „Am luat” în aplicație).
  Future<void> cancelDose(int medId, int timeIndex) async {
    if (!_ready) return;
    await _plugin.cancel(id: 1000 + medId * 10 + timeIndex);
  }
}

/// Ce înseamnă o apăsare pe notificare.
sealed class NoteTap {
  const NoteTap();

  static NoteTap? parse(NotificationResponse r) {
    final raw = r.payload;
    if (raw == null || raw.isEmpty) return null;
    final Map<String, dynamic> p;
    try {
      p = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
    return switch (p['t']) {
      'dose' => DoseTap(p, r.actionId),
      'test' => const TestTap(),
      'stock' || 'other' => const OpenReminders(),
      _ => null,
    };
  }
}

class DoseTap extends NoteTap {
  const DoseTap(this.payload, this.action);
  final Map<String, dynamic> payload;
  final String? action;

  int get medId => payload['m'] as int;

  /// Doza de azi la ora din notificare (dacă s-a apăsat după miezul nopții, cea de ieri).
  DateTime scheduledAt(DateTime now) {
    var at = atTime(now, payload['h'] as String);
    if (at.isAfter(now.add(const Duration(hours: 2)))) at = at.subtract(const Duration(days: 1));
    return at;
  }
}

class TestTap extends NoteTap {
  const TestTap();
}

class OpenReminders extends NoteTap {
  const OpenReminders();
}

/// Execută „Am luat” sau „Amână” dintr-o notificare. Merge și din fundal, fără interfață.
Future<bool> handleDoseAction(DoseTap tap, MedicationRepository repo, NotificationService service) async {
  final now = DateTime.now();
  switch (tap.action) {
    case NoteAction.taken:
      await repo.markTaken(tap.medId, tap.scheduledAt(now), at: now);
      return true;
    case NoteAction.snooze:
      await repo.snooze(tap.medId, tap.scheduledAt(now), now.add(snoozeFor));
      await service.snoozeDose(tap.payload);
      return true;
  }
  return false;
}

/// Butoanele din notificare apăsate cu aplicația închisă: deschide baza, notează și gata.
@pragma('vm:entry-point')
Future<void> onBackgroundNotification(NotificationResponse r) async {
  final tap = NoteTap.parse(r);
  if (tap is! DoseTap || tap.action == null) return;
  try {
    DartPluginRegistrant.ensureInitialized();
    final db = await openDatabase(p.join(await getDatabasesPath(), 'manusa.db'));
    final service = NotificationService();
    await service.init();
    await handleDoseAction(tap, MedicationRepository(db), service);
    await db.close();
  } catch (_) {
    // Dacă nu merge din fundal, doza rămâne nebifată și apare în aplicație.
  }
}
