import 'package:flutter/material.dart' show ThemeMode;
import 'package:shared_preferences/shared_preferences.dart';

/// De unde vin datele mănușii.
enum DataSource {
  /// Mănușă simulată, fără hardware (modul demonstrativ).
  demo('Demo'),

  /// Mănușa legată prin USB la calculator, prin puntea tools/usb_bridge.py.
  usb('USB'),

  /// Mănușa reală, prin Bluetooth (ascunsă din alegere: Wi-Fi în loc de Bluetooth).
  ble('Bluetooth'),

  /// Mănușa reală, prin Wi-Fi: aplicația se leagă direct de serverul mănușii (portul 8765).
  wifi('Wi-Fi');

  /// Ce apare în alegere, în ordinea din machete.
  static const visible = [usb, wifi, demo];

  const DataSource(this.label);
  final String label;
}

/// Setările păstrate pe telefon între porniri.
class AppSettings {
  const AppSettings({
    required this.source,
    required this.alertThreshold,
    required this.vibrateOnAlert,
    required this.onboardingDone,
    this.themeMode = ThemeMode.system,
    this.lastDeviceId,
    this.lastDeviceName,
    this.lastCalibration,
    this.wifiHost,
    this.wifiName,
  });

  final DataSource source;

  /// Indicele 0–100 peste care apare alerta.
  final int alertThreshold;
  final bool vibrateOnAlert;
  final bool onboardingDone;

  /// Tema: ca telefonul, deschisă sau întunecată.
  final ThemeMode themeMode;
  final String? lastDeviceId;
  final String? lastDeviceName;
  final DateTime? lastCalibration;

  /// Adresa mănușii în rețea (ex. 192.168.1.37) și numele ei (ex. Manusa-38E0).
  final String? wifiHost;
  final String? wifiName;

  /// Datele sunt simulate: sesiunile se marchează și nu se amestecă cu cele reale.
  bool get demoMode => source == DataSource.demo;

  static const minThreshold = 20;
  static const maxThreshold = 95;
  static const thresholdStep = 5;

  AppSettings copyWith({
    DataSource? source,
    int? alertThreshold,
    bool? vibrateOnAlert,
    bool? onboardingDone,
    ThemeMode? themeMode,
    String? lastDeviceId,
    String? lastDeviceName,
    DateTime? lastCalibration,
    String? wifiHost,
    String? wifiName,
  }) => AppSettings(
    source: source ?? this.source,
    alertThreshold: alertThreshold ?? this.alertThreshold,
    vibrateOnAlert: vibrateOnAlert ?? this.vibrateOnAlert,
    onboardingDone: onboardingDone ?? this.onboardingDone,
    themeMode: themeMode ?? this.themeMode,
    lastDeviceId: lastDeviceId ?? this.lastDeviceId,
    lastDeviceName: lastDeviceName ?? this.lastDeviceName,
    lastCalibration: lastCalibration ?? this.lastCalibration,
    wifiHost: wifiHost ?? this.wifiHost,
    wifiName: wifiName ?? this.wifiName,
  );
}

class SettingsStore {
  SettingsStore(this._prefs);

  final SharedPreferences _prefs;

  AppSettings load() {
    final cal = _prefs.getInt('lastCalibration');
    final sourceIndex = _prefs.getInt('dataSource');
    // Setările vechi aveau doar „demoMode”; până există mănușa, aplicația pornește cu date simulate.
    var source = sourceIndex != null
        ? DataSource.values[sourceIndex.clamp(0, DataSource.values.length - 1)]
        : ((_prefs.getBool('demoMode') ?? true) ? DataSource.demo : DataSource.wifi);
    // Bluetooth nu mai apare în alegere: cine îl avea salvat trece pe Wi-Fi.
    if (source == DataSource.ble) source = DataSource.wifi;
    return AppSettings(
      source: source,
      alertThreshold: _prefs.getInt('alertThreshold') ?? 60,
      vibrateOnAlert: _prefs.getBool('vibrateOnAlert') ?? true,
      onboardingDone: _prefs.getBool('onboardingDone') ?? false,
      themeMode: ThemeMode.values[(_prefs.getInt('themeMode') ?? 0).clamp(0, ThemeMode.values.length - 1)],
      lastDeviceId: _prefs.getString('lastDeviceId'),
      lastDeviceName: _prefs.getString('lastDeviceName'),
      lastCalibration: cal == null ? null : DateTime.fromMillisecondsSinceEpoch(cal),
      wifiHost: _prefs.getString('wifiHost'),
      wifiName: _prefs.getString('wifiName'),
    );
  }

  Future<void> save(AppSettings s) async {
    await _prefs.setInt('dataSource', s.source.index);
    await _prefs.setInt('alertThreshold', s.alertThreshold);
    await _prefs.setBool('vibrateOnAlert', s.vibrateOnAlert);
    await _prefs.setBool('onboardingDone', s.onboardingDone);
    await _prefs.setInt('themeMode', s.themeMode.index);
    if (s.lastDeviceId != null) await _prefs.setString('lastDeviceId', s.lastDeviceId!);
    if (s.lastDeviceName != null) await _prefs.setString('lastDeviceName', s.lastDeviceName!);
    if (s.lastCalibration != null) await _prefs.setInt('lastCalibration', s.lastCalibration!.millisecondsSinceEpoch);
    if (s.wifiHost != null) await _prefs.setString('wifiHost', s.wifiHost!);
    if (s.wifiName != null) await _prefs.setString('wifiName', s.wifiName!);
  }
}
