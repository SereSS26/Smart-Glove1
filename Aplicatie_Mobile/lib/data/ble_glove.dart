import 'dart:async';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';

import '../core/contract.dart';
import '../core/glove_source.dart';
import '../core/live_packet.dart';

/// Mănușa reală, prin Bluetooth Low Energy.
///
/// Netestat încă pe hardware: firmware-ul BLE nu există (Etapa 2 din plan).
/// Pentru test: întâi nRF Connect pe telefon, apoi aplicația.
class BleGlove implements GloveSource {
  BleGlove(this._ble);

  final FlutterReactiveBle _ble;

  static final _service = Uuid.parse(GloveContract.serviceUuid);
  static final _live = Uuid.parse(GloveContract.liveUuid);
  static final _control = Uuid.parse(GloveContract.controlUuid);
  static const _retryDelay = Duration(seconds: 2);

  final _connection = StreamController<GloveConnection>.broadcast();
  final _packets = StreamController<LivePacket>.broadcast();
  GloveConnection _current = GloveConnection.disconnected;
  StreamSubscription<ConnectionStateUpdate>? _connectSub;
  StreamSubscription<List<int>>? _liveSub;
  Timer? _retry;
  String? _deviceId;
  String? _name;
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
  String? get deviceName => _name ?? _deviceId;

  @override
  bool get isSimulated => false;

  void _setConnection(GloveConnection c) {
    _current = c;
    if (!_connection.isClosed) _connection.add(c);
  }

  @override
  Future<void> connect(String deviceId, {String? name}) async {
    _deviceId = deviceId;
    _name = name ?? _name;
    _wanted = true;
    _open();
  }

  void _open() {
    if (_disposed || !_wanted || _deviceId == null) return;
    _retry?.cancel();
    _connectSub?.cancel();
    _setConnection(GloveConnection.connecting);
    _connectSub = _ble
        .connectToDevice(
          id: _deviceId!,
          servicesWithCharacteristicsToDiscover: {
            _service: [_live, _control],
          },
          connectionTimeout: const Duration(seconds: 10),
        )
        .listen(_onUpdate, onError: (_) => _scheduleRetry());
  }

  void _onUpdate(ConnectionStateUpdate update) {
    switch (update.connectionState) {
      case DeviceConnectionState.connected:
        _setConnection(GloveConnection.connected);
        _subscribeLive();
      case DeviceConnectionState.disconnected:
        _liveSub?.cancel();
        _scheduleRetry();
      case DeviceConnectionState.connecting:
      case DeviceConnectionState.disconnecting:
        break;
    }
  }

  void _subscribeLive() {
    _liveSub?.cancel();
    final characteristic = QualifiedCharacteristic(serviceId: _service, characteristicId: _live, deviceId: _deviceId!);
    _liveSub = _ble.subscribeToCharacteristic(characteristic).listen((bytes) {
      try {
        _packets.add(LivePacket.decode(bytes));
      } on FormatException {
        // Un pachet stricat se ignoră; ecranul arată „Fără date” dacă nu mai vin pachete bune.
      }
    }, onError: (_) => _scheduleRetry());
  }

  /// Reconectare automată cât timp utilizatorul vrea conexiunea.
  void _scheduleRetry() {
    _setConnection(_wanted ? GloveConnection.connecting : GloveConnection.disconnected);
    if (!_wanted || _disposed) return;
    _retry?.cancel();
    _retry = Timer(_retryDelay, _open);
  }

  @override
  Future<void> disconnect() async {
    _wanted = false;
    _retry?.cancel();
    await _liveSub?.cancel();
    await _connectSub?.cancel();
    _setConnection(GloveConnection.disconnected);
  }

  @override
  Future<void> send(ControlCommand command, [int value = 0]) async {
    if (_current != GloveConnection.connected || _deviceId == null) return;
    final characteristic = QualifiedCharacteristic(serviceId: _service, characteristicId: _control, deviceId: _deviceId!);
    await _ble.writeCharacteristicWithResponse(characteristic, value: [command.code, value.clamp(0, 255)]);
  }

  @override
  void dispose() {
    _disposed = true;
    _wanted = false;
    _retry?.cancel();
    _liveSub?.cancel();
    _connectSub?.cancel();
    _connection.close();
    _packets.close();
  }
}

/// Un dispozitiv găsit la scanare.
class FoundGlove {
  const FoundGlove({required this.id, required this.name, required this.rssi});
  final String id;
  final String name;
  final int rssi;
}

/// Scanarea după mănuși din apropiere.
class GloveScanner {
  GloveScanner(this._ble);

  final FlutterReactiveBle _ble;

  /// Dispozitivele care se anunță cu serviciul mănușii sau cu numele „Manusa…”.
  Stream<FoundGlove> scan() {
    final service = Uuid.parse(GloveContract.serviceUuid);
    return _ble
        .scanForDevices(withServices: const [], scanMode: ScanMode.lowLatency)
        .where((d) => d.serviceUuids.contains(service) || d.name.startsWith(GloveContract.namePrefix))
        .map((d) => FoundGlove(id: d.id, name: d.name.isEmpty ? d.id : d.name, rssi: d.rssi));
  }

  Stream<BleStatus> get status => _ble.statusStream;
}
