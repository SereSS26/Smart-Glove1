import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../core/contract.dart';
import '../core/glove_source.dart';
import '../core/live_packet.dart';

/// Mănușa legată prin USB la calculator. Datele trec prin puntea `tools/usb_bridge.py`,
/// care ascultă pe calculator la portul 8765; telefonul sau emulatorul ajung la ea prin `adb reverse`.
///
/// Protocol (text, câte o linie): mănușa → aplicație `P <28 cifre hex>` = pachetul Live;
/// aplicație → mănușă `C <cod> <valoare>`.
class UsbGlove implements GloveSource {
  UsbGlove({this.host = '127.0.0.1', this.port = 8765});

  final String host;
  final int port;

  static const _retryDelay = Duration(seconds: 2);

  final _connection = StreamController<GloveConnection>.broadcast();
  final _packets = StreamController<LivePacket>.broadcast();
  GloveConnection _current = GloveConnection.disconnected;
  Socket? _socket;
  StreamSubscription<String>? _lines;
  Timer? _retry;
  bool _wanted = false;
  bool _disposed = false;

  @override
  Stream<GloveConnection> get connection async* {
    yield _current;
    yield* _connection.stream;
  }

  @override
  GloveConnection get currentConnection => _current;

  @override
  Stream<LivePacket> get packets => _packets.stream;

  @override
  String? get deviceName => 'Mănușă prin USB';

  @override
  bool get isSimulated => false;

  void _setConnection(GloveConnection c) {
    _current = c;
    if (!_connection.isClosed) _connection.add(c);
  }

  @override
  Future<void> connect(String deviceId, {String? name}) async {
    _wanted = true;
    await _open();
  }

  Future<void> _open() async {
    if (_disposed || !_wanted) return;
    _retry?.cancel();
    _setConnection(GloveConnection.connecting);
    try {
      final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 3));
      if (_disposed || !_wanted) {
        socket.destroy();
        return;
      }
      _socket = socket;
      _setConnection(GloveConnection.connected);
      _lines = utf8.decoder
          .bind(socket)
          .transform(const LineSplitter())
          .listen(_onLine, onDone: _onClosed, onError: (_) => _onClosed(), cancelOnError: true);
    } on Object {
      _scheduleRetry();
    }
  }

  void _onLine(String line) {
    if (!line.startsWith('P ')) return;
    final hex = line.substring(2).trim();
    if (hex.length != GloveContract.livePacketLength * 2) return;
    try {
      final bytes = [for (var i = 0; i < hex.length; i += 2) int.parse(hex.substring(i, i + 2), radix: 16)];
      _packets.add(LivePacket.decode(bytes));
    } on FormatException {
      // Un pachet stricat se ignoră; ecranul arată „Fără date” dacă nu mai vin pachete bune.
    }
  }

  void _onClosed() {
    _socket?.destroy();
    _socket = null;
    _scheduleRetry();
  }

  /// Reconectare automată cât timp utilizatorul vrea conexiunea (de ex. puntea a fost repornită).
  void _scheduleRetry() {
    if (_disposed) return;
    _setConnection(_wanted ? GloveConnection.connecting : GloveConnection.disconnected);
    if (!_wanted) return;
    _retry?.cancel();
    _retry = Timer(_retryDelay, _open);
  }

  @override
  Future<void> disconnect() async {
    _wanted = false;
    _retry?.cancel();
    await _lines?.cancel();
    _socket?.destroy();
    _socket = null;
    _setConnection(GloveConnection.disconnected);
  }

  @override
  Future<void> send(ControlCommand command, [int value = 0]) async {
    final socket = _socket;
    if (socket == null) return;
    socket.write('C ${command.code} ${value.clamp(0, 255)}\n');
    await socket.flush();
  }

  @override
  void dispose() {
    _disposed = true;
    _wanted = false;
    _retry?.cancel();
    _lines?.cancel();
    _socket?.destroy();
    _connection.close();
    _packets.close();
  }
}
