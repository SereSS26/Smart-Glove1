/// Contractul BLE v1 dintre mănușă și aplicație (vezi ghidul „Ghid Solo și Artur”).
/// Orice schimbare aici trebuie făcută la fel și în firmware.
abstract final class GloveContract {
  static const version = 1;

  static const serviceUuid = '4d414e55-0001-4a5f-9c1d-0a1b2c3d4e5f';
  static const liveUuid = '4d414e55-0002-4a5f-9c1d-0a1b2c3d4e5f';
  static const controlUuid = '4d414e55-0003-4a5f-9c1d-0a1b2c3d4e5f';

  /// Numele cu care se anunță mănușa prin Bluetooth (ex. „Manusa-A1F3”).
  static const namePrefix = 'Manusa';

  static const livePacketLength = 14;
  static const packetsPerSecond = 10;

  /// Octet de îndoire = 255: degetul nu e calibrat (clarificare propusă, de confirmat cu Solo).
  static const fingerNotCalibrated = 255;

  /// Octet de baterie = 255: mănușa e alimentată prin USB.
  static const batteryUsb = 255;

  static const fingerCount = 5;
}

/// Comenzile scrise de telefon în caracteristica Control: [comandă, valoare].
enum ControlCommand {
  calibrateOpen(1),
  calibrateFist(2),
  calibrateGyro(3),
  startSession(4),
  stopSession(5),
  alertThreshold(6),
  vibrate(7);

  const ControlCommand(this.code);
  final int code;
}

/// Valorile comenzii 7.
abstract final class VibrationPattern {
  static const alert = 1;
  static const confirm = 2;
}

/// Starea mâinii, octetul 11 din pachetul Live.
enum HandState {
  rest(0, 'repaus'),
  posture(1, 'postură'),
  action(2, 'acțiune');

  const HandState(this.code, this.label);
  final int code;
  final String label;

  static HandState fromCode(int code) =>
      HandState.values.firstWhere((s) => s.code == code, orElse: () => throw FormatException('Stare necunoscută: $code'));
}

/// Biții din octetul 13 (clarificare propusă, de confirmat cu Solo).
abstract final class GloveFlags {
  static const flexCalibrated = 1 << 0;
  static const gyroCalibrated = 1 << 1;
  static const sessionActive = 1 << 2;
  static const buttonPressed = 1 << 3;
}
