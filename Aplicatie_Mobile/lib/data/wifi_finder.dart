import 'dart:convert';
import 'dart:io';

/// O mănușă găsită în rețea: numele (ex. Manusa-38E0) și adresa ei.
class WifiGlove {
  const WifiGlove(this.name, this.host);
  final String name;
  final String host;
}

/// Caută mănușile din rețeaua locală: trimite „MANUSA?” către toată rețeaua (UDP 8766),
/// iar fiecare mănușă răspunde `MANUSA nume adresă`.
/// În emulator căutarea nu primește răspuns (rețeaua emulatorului e izolată): acolo adresa se scrie de mână.
class WifiFinder {
  static const port = 8766;

  static Future<List<WifiGlove>> find({Duration timeout = const Duration(seconds: 2)}) async {
    final found = <String, WifiGlove>{};
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;
      socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final d = socket!.receive();
        if (d == null) return;
        final g = parse(utf8.decode(d.data, allowMalformed: true), fallbackHost: d.address.address);
        if (g != null) found[g.host] = g;
      });
      final query = utf8.encode('MANUSA?');
      for (var i = 0; i < 3; i++) {
        socket.send(query, InternetAddress('255.255.255.255'), port);
        await Future<void>.delayed(timeout ~/ 3);
      }
    } on SocketException {
      // Fără rețea: lista rămâne goală.
    } finally {
      socket?.close();
    }
    return found.values.toList();
  }

  /// „MANUSA Manusa-38E0 192.168.1.37” → mănușa; orice altceva → null.
  static WifiGlove? parse(String reply, {String? fallbackHost}) {
    final parts = reply.trim().split(RegExp(r'\s+'));
    if (parts.length < 2 || parts.first != 'MANUSA') return null;
    final host = parts.length >= 3 ? parts[2] : fallbackHost;
    if (host == null || InternetAddress.tryParse(host) == null) return null;
    return WifiGlove(parts[1], host);
  }

  /// O adresă scrisă de mână e bună dacă e un IPv4 (ex. 192.168.1.37).
  static bool isValidHost(String host) {
    final a = InternetAddress.tryParse(host.trim());
    return a != null && a.type == InternetAddressType.IPv4;
  }
}
