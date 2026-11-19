import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Notificările locale pentru alerte. Nimic nu pleacă din telefon.
class NotificationService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _channel = AndroidNotificationDetails(
    'alerte_tremor',
    'Alerte tremor',
    channelDescription: 'Când tremorul trece de pragul ales',
    importance: Importance.high,
    priority: Priority.high,
  );

  Future<void> init() async {
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );
      _ready = true;
    } catch (_) {
      // Fără notificări (ex. în teste); alerta rămâne vizibilă în aplicație.
    }
  }

  /// Pe Android 13+ trebuie cerută permisiunea; o cerem la prima pornire.
  Future<void> requestPermission() async {
    if (!_ready) return;
    await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    await _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert: true, sound: true);
  }

  Future<void> showAlert({required int index, required int threshold}) async {
    if (!_ready) return;
    await _plugin.show(
      id: 1,
      title: 'Tremor peste prag',
      body: 'Indicele de tremor a ajuns la $index (pragul tău: $threshold).',
      notificationDetails: const NotificationDetails(android: _channel, iOS: DarwinNotificationDetails()),
    );
  }
}
