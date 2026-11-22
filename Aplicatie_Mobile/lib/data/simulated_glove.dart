import 'dart:async';
import 'dart:math';

import '../core/contract.dart';
import '../core/glove_source.dart';
import '../core/live_packet.dart';
import '../core/tests.dart';

/// O fază din scenariul simulat: cât durează și cum arată tremorul în ea.
class _Phase {
  const _Phase(this.seconds, this.index, this.frequency, this.state);
  final int seconds;
  final int index;
  final double frequency;
  final HandState state;
}

/// Mănușă simulată: produce pachete în formatul contractului, de 10 ori pe secundă,
/// și răspunde la comenzi ca firmware-ul. Pachetele trec prin encode/decode,
/// deci simulatorul verifică și codul de decodare.
class SimulatedGlove implements GloveSource {
  SimulatedGlove({int seed = 7, this.tick = const Duration(milliseconds: 100), this.calibrated = true}) : _random = Random(seed) {
    if (calibrated) _flags |= GloveFlags.flexCalibrated | GloveFlags.gyroCalibrated;
  }

  final Duration tick;
  final bool calibrated;
  final Random _random;

  /// Un ciclu de ~2 minute: liniște, tremor moderat, un episod puternic (peste pragul implicit 60).
  static const _scenario = [
    _Phase(20, 18, 0, HandState.rest),
    _Phase(25, 48, 4.7, HandState.rest),
    _Phase(15, 72, 5.2, HandState.rest),
    _Phase(20, 52, 4.9, HandState.posture),
    _Phase(15, 25, 0, HandState.action),
    _Phase(20, 44, 4.5, HandState.rest),
  ];

  final _connection = StreamController<GloveConnection>.broadcast();
  final _packets = StreamController<LivePacket>.broadcast();
  GloveConnection _current = GloveConnection.disconnected;
  Timer? _timer;
  int _ticks = 0;
  int _flags = 0;
  bool _openCalibrated = false;
  double _index = 18;
  double _frequency = 0;

  TestKind? _test;
  int _testStart = 0;

  /// În timpul unui test ghidat, mănușa simulată se poartă ca o mână reală la testul acela:
  /// la postural tremorul e mai mare, la tapping degetele se închid de ~3 ori pe secundă și obosesc spre final.
  void setTest(TestKind? test) {
    _test = test;
    _testStart = _ticks;
  }

  static const _testPhases = {
    TestKind.rest: _Phase(1, 41, 4.8, HandState.rest),
    TestKind.postural: _Phase(1, 54, 5.1, HandState.posture),
    TestKind.kinetic: _Phase(1, 47, 4.6, HandState.action),
    TestKind.tappingGlove: _Phase(1, 24, 0, HandState.action),
    TestKind.tappingScreen: _Phase(1, 30, 4.7, HandState.rest),
  };

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
  String? get deviceName => 'Mănușă simulată';

  @override
  bool get isSimulated => true;

  void _setConnection(GloveConnection c) {
    _current = c;
    if (!_connection.isClosed) _connection.add(c);
  }

  @override
  Future<void> connect(String deviceId, {String? name}) async {
    if (_current != GloveConnection.disconnected) return;
    _setConnection(GloveConnection.connecting);
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (_connection.isClosed) return;
    _setConnection(GloveConnection.connected);
    _timer = Timer.periodic(tick, (_) => _emit());
  }

  @override
  Future<void> disconnect() async {
    _timer?.cancel();
    _timer = null;
    _setConnection(GloveConnection.disconnected);
  }

  @override
  Future<void> send(ControlCommand command, [int value = 0]) async {
    switch (command) {
      case ControlCommand.calibrateOpen:
        _flags &= ~GloveFlags.flexCalibrated;
        Timer(const Duration(milliseconds: 800), () => _openCalibrated = true);
      case ControlCommand.calibrateFist:
        Timer(const Duration(milliseconds: 800), () {
          if (_openCalibrated) _flags |= GloveFlags.flexCalibrated;
        });
      case ControlCommand.calibrateGyro:
        _flags &= ~GloveFlags.gyroCalibrated;
        Timer(const Duration(milliseconds: 1800), () => _flags |= GloveFlags.gyroCalibrated);
      case ControlCommand.startSession:
        _flags |= GloveFlags.sessionActive;
      case ControlCommand.stopSession:
        _flags &= ~GloveFlags.sessionActive;
      case ControlCommand.alertThreshold:
      case ControlCommand.vibrate:
        // Mănușa simulată nu are motor; comanda e acceptată fără efect.
        break;
    }
  }

  _Phase _phaseAt(double seconds) {
    final total = _scenario.fold<int>(0, (sum, p) => sum + p.seconds);
    var t = seconds % total;
    for (final p in _scenario) {
      if (t < p.seconds) return p;
      t -= p.seconds;
    }
    return _scenario.last;
  }

  void _emit() {
    _ticks++;
    // Timpul scenariului avansează 0,1 s pe pachet, indiferent de [tick] (testele îl accelerează).
    final seconds = _ticks / GloveContract.packetsPerSecond;
    final phase = _test == null ? _phaseAt(seconds) : _testPhases[_test]!;

    // Valorile se apropie lin de ținta fazei, cu puțin zgomot, ca la o măsurătoare reală.
    _index += (phase.index - _index) * 0.04 + (_random.nextDouble() - 0.5) * 2.4;
    _index = _index.clamp(0, 100);
    final targetFreq = phase.frequency == 0 ? 0.0 : phase.frequency + (_random.nextDouble() - 0.5) * 0.2;
    _frequency = phase.frequency == 0 ? 0 : (_frequency == 0 ? targetFreq : _frequency + (targetFreq - _frequency) * 0.1);

    final flexOk = _flags & GloveFlags.flexCalibrated != 0;
    final tapping = _test == TestKind.tappingGlove;
    final t = (_ticks - _testStart) / GloveContract.packetsPerSecond;
    // Tapping: ~3 atingeri pe secundă, amplitudinea scade ușor (oboseală).
    final tapAmp = 42 * (1 - 0.012 * t);
    final fingers = <int?>[
      for (var i = 0; i < GloveContract.fingerCount; i++)
        !flexOk
            ? null
            : (tapping && i < 2
                      ? 48 + tapAmp * sin(2 * pi * 3.1 * t + (i == 0 ? 0.4 : 0)) + (_random.nextDouble() - 0.5) * 4
                      : 40 + 35 * sin(seconds * 0.35 + i * 0.9) + (_random.nextDouble() - 0.5) * 3)
                  .round()
                  .clamp(0, 100),
    ];

    final packet = LivePacket(
      fingers: fingers,
      frequencyHz: double.parse(_frequency.toStringAsFixed(2)),
      rmsDps: _index * 0.3,
      tremorIndex: _index.round(),
      state: phase.state,
      batteryPercent: null,
      flags: _flags,
    );
    if (!_packets.isClosed) _packets.add(LivePacket.decode(packet.encode()));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _connection.close();
    _packets.close();
  }
}
