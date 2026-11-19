import 'contract.dart';
import 'live_packet.dart';

enum GloveConnection { disconnected, connecting, connected }

/// Interfața comună pentru mănușa reală (BLE) și cea simulată.
/// Ecranele lucrează doar cu ea, deci nu știu de unde vin datele.
abstract class GloveSource {
  /// Starea curentă a conexiunii; fluxul începe cu valoarea de acum.
  Stream<GloveConnection> get connection;
  GloveConnection get currentConnection;

  /// Pachetele Live, de 10 ori pe secundă cât timp e conectată.
  Stream<LivePacket> get packets;

  /// Numele afișat al mănușii (ex. „Manusa-A1F3”); null dacă nu e aleasă niciuna.
  String? get deviceName;

  bool get isSimulated;

  Future<void> connect(String deviceId, {String? name});
  Future<void> disconnect();
  Future<void> send(ControlCommand command, [int value = 0]);
  void dispose();
}
