import 'package:flutter_test/flutter_test.dart';
import 'package:manusa_app/core/contract.dart';
import 'package:manusa_app/core/live_packet.dart';

void main() {
  // Același pachet scris de mână se poate folosi și la testarea firmware-ului.
  // 4,60 Hz = 460 = 0x01CC; 12,34 °/s = 1234 = 0x04D2.
  const known = [1, 80, 65, 40, 30, 10, 0xCC, 0x01, 0xD2, 0x04, 58, 0, 255, 0x03];

  test('decodează un pachet cunoscut', () {
    final p = LivePacket.decode(known);
    expect(p.fingers, [80, 65, 40, 30, 10]);
    expect(p.frequencyHz, closeTo(4.60, 1e-9));
    expect(p.rmsDps, closeTo(12.34, 1e-9));
    expect(p.tremorIndex, 58);
    expect(p.state, HandState.rest);
    expect(p.onUsb, isTrue);
    expect(p.flexCalibrated, isTrue);
    expect(p.gyroCalibrated, isTrue);
    expect(p.sessionActive, isFalse);
  });

  test('255 la deget înseamnă necalibrat, procent la baterie', () {
    final bytes = [...known]
      ..[3] = 255
      ..[12] = 73
      ..[13] = 0;
    final p = LivePacket.decode(bytes);
    expect(p.fingers[2], isNull);
    expect(p.batteryPercent, 73);
    expect(p.flexCalibrated, isFalse);
  });

  test('encode și decode sunt inverse', () {
    final p = LivePacket.decode(known);
    expect(p.encode(), known);
  });

  test('respinge lungimea greșită', () {
    expect(() => LivePacket.decode(known.sublist(0, 13)), throwsFormatException);
  });

  test('respinge altă versiune de contract', () {
    expect(() => LivePacket.decode([2, ...known.sublist(1)]), throwsFormatException);
  });

  test('respinge valori în afara domeniului', () {
    expect(() => LivePacket.decode([...known]..[10] = 101), throwsFormatException);
    expect(() => LivePacket.decode([...known]..[11] = 9), throwsFormatException);
    expect(() => LivePacket.decode([...known]..[1] = 150), throwsFormatException);
  });

  test('pachetul are 14 octeți', () {
    expect(known.length, GloveContract.livePacketLength);
  });
}
