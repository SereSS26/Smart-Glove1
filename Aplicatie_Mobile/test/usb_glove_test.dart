import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:manusa_app/core/contract.dart';
import 'package:manusa_app/core/glove_source.dart';
import 'package:manusa_app/core/live_packet.dart';
import 'package:manusa_app/data/usb_glove.dart';

void main() {
  test('primește pachetele punții USB și îi trimite comenzile', () async {
    // O punte falsă: trimite o linie de informații, un pachet stricat și un pachet bun (ca firmware-ul glove.cpp).
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final commands = <String>[];
    server.listen((client) {
      client.write('# mesaj de informare\nP 0102\nP 01ffffffffff000034000200ff02\n');
      utf8.decoder.bind(client).transform(const LineSplitter()).listen(commands.add);
    });

    final glove = UsbGlove(port: server.port);
    final packets = <LivePacket>[];
    final sub = glove.packets.listen(packets.add);
    await glove.connect('usb');
    expect(glove.currentConnection, GloveConnection.connected);
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(packets, hasLength(1));
    expect(packets.single.fingers, everyElement(isNull));
    expect(packets.single.rmsDps, closeTo(0.52, 1e-9));
    expect(packets.single.tremorIndex, 2);
    expect(packets.single.onUsb, isTrue);
    expect(packets.single.gyroCalibrated, isTrue);

    await glove.send(ControlCommand.calibrateOpen);
    await glove.send(ControlCommand.alertThreshold, 65);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(commands, ['C 1 0', 'C 6 65']);

    await sub.cancel();
    glove.dispose();
    await server.close();
  });

  test('fără punte pornită rămâne în „se conectează” și reîncearcă', () async {
    final glove = UsbGlove(port: 1); // portul 1 nu ascultă nimic
    await glove.connect('usb');
    expect(glove.currentConnection, GloveConnection.connecting);
    glove.dispose();
  });
}
