import 'dart:typed_data';

import 'contract.dart';

/// Un pachet Live: ce trimite mănușa de 10 ori pe secundă.
///
/// Format (14 octeți, little-endian):
/// [0] versiune · [1–5] îndoire F1–F5 în % · [6–7] frecvență, u16, sutimi de Hz ·
/// [8–9] RMS, u16, sutimi de °/s · [10] indice tremor 0–100 · [11] stare ·
/// [12] baterie % (255 = USB) · [13] flaguri
class LivePacket {
  const LivePacket({
    required this.fingers,
    required this.frequencyHz,
    required this.rmsDps,
    required this.tremorIndex,
    required this.state,
    required this.batteryPercent,
    required this.flags,
  });

  /// Îndoirea fiecărui deget, 0–100 %; null = deget necalibrat.
  final List<int?> fingers;

  /// Frecvența dominantă a tremorului; 0 = nu e tremor măsurabil.
  final double frequencyHz;
  final double rmsDps;

  /// 0–100.
  final int tremorIndex;
  final HandState state;

  /// null = alimentată prin USB.
  final int? batteryPercent;
  final int flags;

  bool get onUsb => batteryPercent == null;
  bool get hasTremor => frequencyHz > 0;
  bool get flexCalibrated => flags & GloveFlags.flexCalibrated != 0;
  bool get gyroCalibrated => flags & GloveFlags.gyroCalibrated != 0;
  bool get sessionActive => flags & GloveFlags.sessionActive != 0;
  bool get buttonPressed => flags & GloveFlags.buttonPressed != 0;

  /// Transformă octeții primiți prin BLE în pachet. Aruncă [FormatException] dacă pachetul e greșit.
  static LivePacket decode(List<int> bytes) {
    if (bytes.length != GloveContract.livePacketLength) {
      throw FormatException('Pachet Live de ${bytes.length} octeți; aștept ${GloveContract.livePacketLength}.');
    }
    final data = ByteData.sublistView(Uint8List.fromList(bytes));
    final version = data.getUint8(0);
    if (version != GloveContract.version) {
      throw FormatException('Versiune de contract $version; aplicația știe versiunea ${GloveContract.version}.');
    }
    final fingers = <int?>[for (var i = 1; i <= GloveContract.fingerCount; i++) _finger(data.getUint8(i))];
    final index = data.getUint8(10);
    if (index > 100) throw FormatException('Indice de tremor $index; maximum 100.');
    final battery = data.getUint8(12);
    return LivePacket(
      fingers: fingers,
      frequencyHz: data.getUint16(6, Endian.little) / 100,
      rmsDps: data.getUint16(8, Endian.little) / 100,
      tremorIndex: index,
      state: HandState.fromCode(data.getUint8(11)),
      batteryPercent: battery == GloveContract.batteryUsb ? null : battery.clamp(0, 100),
      flags: data.getUint8(13),
    );
  }

  static int? _finger(int raw) {
    if (raw == GloveContract.fingerNotCalibrated) return null;
    if (raw > 100) throw FormatException('Îndoire $raw %; maximum 100.');
    return raw;
  }

  /// Operația inversă; o folosesc simulatorul și testele.
  Uint8List encode() {
    final data = ByteData(GloveContract.livePacketLength)
      ..setUint8(0, GloveContract.version)
      ..setUint16(6, (frequencyHz * 100).round().clamp(0, 0xFFFF), Endian.little)
      ..setUint16(8, (rmsDps * 100).round().clamp(0, 0xFFFF), Endian.little)
      ..setUint8(10, tremorIndex.clamp(0, 100))
      ..setUint8(11, state.code)
      ..setUint8(12, batteryPercent?.clamp(0, 100) ?? GloveContract.batteryUsb)
      ..setUint8(13, flags);
    for (var i = 0; i < GloveContract.fingerCount; i++) {
      data.setUint8(i + 1, fingers[i]?.clamp(0, 100) ?? GloveContract.fingerNotCalibrated);
    }
    return data.buffer.asUint8List();
  }
}
