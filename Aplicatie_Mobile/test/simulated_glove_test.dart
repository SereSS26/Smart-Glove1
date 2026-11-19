import 'package:flutter_test/flutter_test.dart';
import 'package:manusa_app/core/contract.dart';
import 'package:manusa_app/core/glove_source.dart';
import 'package:manusa_app/core/live_packet.dart';
import 'package:manusa_app/data/simulated_glove.dart';

void main() {
  test('se conectează și trimite ~10 pachete pe secundă', () async {
    final glove = SimulatedGlove();
    final packets = <LivePacket>[];
    final sub = glove.packets.listen(packets.add);
    await glove.connect('demo');
    expect(glove.currentConnection, GloveConnection.connected);
    await Future<void>.delayed(const Duration(milliseconds: 1050));
    expect(packets.length, inInclusiveRange(9, 11));
    expect(packets.every((p) => p.tremorIndex >= 0 && p.tremorIndex <= 100), isTrue);
    expect(packets.every((p) => p.onUsb), isTrue);
    await sub.cancel();
    glove.dispose();
  });

  test('ajunge peste pragul de 60 în episodul puternic', () async {
    final glove = SimulatedGlove(tick: const Duration(milliseconds: 1));
    var max = 0;
    final sub = glove.packets.listen((p) => max = p.tremorIndex > max ? p.tremorIndex : max);
    await glove.connect('demo');
    // ~65 s de scenariu, rulat accelerat.
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    expect(max, greaterThan(60));
    await sub.cancel();
    glove.dispose();
  });

  test('calibrarea setează flagul abia după mână deschisă și pumn', () async {
    final glove = SimulatedGlove(calibrated: false);
    LivePacket? last;
    final sub = glove.packets.listen((p) => last = p);
    await glove.connect('demo');
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(last!.flexCalibrated, isFalse);
    expect(last!.fingers.every((f) => f == null), isTrue);

    await glove.send(ControlCommand.calibrateOpen);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    await glove.send(ControlCommand.calibrateFist);
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    expect(last!.flexCalibrated, isTrue);
    expect(last!.fingers.every((f) => f != null), isTrue);
    await sub.cancel();
    glove.dispose();
  });
}
