import 'dart:async';

import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/contract.dart';
import '../core/glove_source.dart';
import '../core/live_packet.dart';
import '../data/ble_glove.dart';
import '../data/db/app_database.dart';
import '../data/db/models.dart';
import '../data/settings_store.dart';
import '../data/simulated_glove.dart';
import '../data/usb_glove.dart';
import '../services/alert_monitor.dart';
import '../services/notification_service.dart';

// Furnizate din main.dart, după ce sunt deschise.
final prefsProvider = Provider<SharedPreferences>((_) => throw UnimplementedError('Se setează în main.dart'));
final databaseProvider = Provider<AppDatabase>((_) => throw UnimplementedError('Se setează în main.dart'));
final notificationsProvider = Provider<NotificationService>((_) => NotificationService());

final bleProvider = Provider<FlutterReactiveBle>((_) => FlutterReactiveBle());
final scannerProvider = Provider<GloveScanner>((ref) => GloveScanner(ref.watch(bleProvider)));

// ---- Setări ----

class SettingsNotifier extends Notifier<AppSettings> {
  late SettingsStore _store;

  @override
  AppSettings build() {
    _store = SettingsStore(ref.watch(prefsProvider));
    return _store.load();
  }

  void update(AppSettings Function(AppSettings s) change) {
    state = change(state);
    _store.save(state);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

// ---- Mănușa ----

/// Mănușa curentă, după sursa aleasă: simulată, prin USB (puntea de pe calculator) sau prin Bluetooth.
/// Când se schimbă sursa, cea veche se închide și se creează una nouă.
final gloveSourceProvider = Provider<GloveSource>((ref) {
  final kind = ref.watch(settingsProvider.select((s) => s.source));
  final settings = ref.read(settingsProvider);
  final GloveSource source = switch (kind) {
    DataSource.demo => SimulatedGlove(),
    DataSource.usb => UsbGlove(),
    DataSource.ble => BleGlove(ref.read(bleProvider)),
  };
  ref.onDispose(source.dispose);
  switch (kind) {
    case DataSource.demo:
    case DataSource.usb:
      source.connect(kind.name);
    case DataSource.ble:
      // Se reconectează singură la ultima mănușă folosită.
      if (settings.lastDeviceId != null) source.connect(settings.lastDeviceId!, name: settings.lastDeviceName);
  }
  return source;
});

final connectionProvider = StreamProvider<GloveConnection>((ref) => ref.watch(gloveSourceProvider).connection);

/// Ce arată ecranul Live: ultimul pachet, dacă datele sunt vechi și ultimele 30 s de indice.
class LiveState {
  const LiveState({this.packet, this.receivedAt, this.stale = true, this.history = const []});

  final LivePacket? packet;
  final DateTime? receivedAt;

  /// Adevărat dacă n-a venit niciun pachet în ultimele 2 secunde: valorile nu se arată ca live.
  final bool stale;
  final List<double> history;

  static const historyLength = 30 * GloveContract.packetsPerSecond;
  static const staleAfter = Duration(seconds: 2);
}

class LiveNotifier extends Notifier<LiveState> {
  @override
  LiveState build() {
    final source = ref.watch(gloveSourceProvider);
    final sub = source.packets.listen(_onPacket);
    final timer = Timer.periodic(const Duration(milliseconds: 500), (_) => _checkStale());
    ref.onDispose(() {
      sub.cancel();
      timer.cancel();
    });
    return const LiveState();
  }

  void _onPacket(LivePacket p) {
    final history = [...state.history, p.tremorIndex.toDouble()];
    if (history.length > LiveState.historyLength) history.removeRange(0, history.length - LiveState.historyLength);
    state = LiveState(packet: p, receivedAt: DateTime.now(), stale: false, history: history);
  }

  void _checkStale() {
    final at = state.receivedAt;
    if (!state.stale && at != null && DateTime.now().difference(at) > LiveState.staleAfter) {
      state = LiveState(packet: state.packet, receivedAt: at, stale: true, history: state.history);
    }
  }
}

final liveProvider = NotifierProvider<LiveNotifier, LiveState>(LiveNotifier.new);

// ---- Istoric ----

/// Sesiunile încheiate: în modul demonstrativ doar cele simulate, altfel doar cele reale.
final historyProvider = FutureProvider<List<SessionRecord>>((ref) {
  final demo = ref.watch(settingsProvider.select((s) => s.demoMode));
  return ref.watch(databaseProvider).sessions(simulated: demo);
});

// ---- Sesiunea în curs ----

class ActiveSession {
  const ActiveSession({required this.id, required this.startedAt, required this.activity, required this.notes, required this.marks});

  final int id;
  final DateTime startedAt;
  final HandState activity;
  final List<String> notes;
  final int marks;

  ActiveSession copyWith({HandState? activity, List<String>? notes, int? marks}) => ActiveSession(
    id: id,
    startedAt: startedAt,
    activity: activity ?? this.activity,
    notes: notes ?? this.notes,
    marks: marks ?? this.marks,
  );
}

class SessionNotifier extends Notifier<ActiveSession?> {
  Timer? _timer;
  final _pending = <SampleRecord>[];

  AppDatabase get _db => ref.read(databaseProvider);

  @override
  ActiveSession? build() {
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  Future<void> start() async {
    if (state != null) return;
    final now = DateTime.now();
    final simulated = ref.read(settingsProvider).demoMode;
    final id = await _db.startSession(at: now, activity: HandState.rest, simulated: simulated);
    state = ActiveSession(id: id, startedAt: now, activity: HandState.rest, notes: const [], marks: 0);
    await ref.read(gloveSourceProvider).send(ControlCommand.startSession);
    await _wakelock(true);
    // Un eșantion pe secundă; se scriu în bază câte 10 deodată.
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _sample());
  }

  void _sample() {
    final s = state;
    final live = ref.read(liveProvider);
    final p = live.packet;
    if (s == null || p == null || live.stale) return;
    _pending.add(
      SampleRecord(
        at: DateTime.now(),
        frequency: p.frequencyHz,
        rms: p.rmsDps,
        index: p.tremorIndex,
        state: s.activity,
        fingers: p.fingers,
      ),
    );
    if (_pending.length >= 10) _flush();
  }

  Future<void> _flush() async {
    final s = state;
    if (s == null || _pending.isEmpty) return;
    final batch = [..._pending];
    _pending.clear();
    await _db.addSamples(s.id, batch);
  }

  void setActivity(HandState activity) => state = state?.copyWith(activity: activity);

  Future<void> addNote(String text) async {
    final s = state;
    final note = text.trim();
    if (s == null || note.isEmpty) return;
    final notes = [...s.notes, note];
    state = s.copyWith(notes: notes);
    await _db.setNote(s.id, notes.join('; '));
    await _db.addEvent(s.id, EventRecord(at: DateTime.now(), kind: EventKind.note, text: note));
  }

  Future<void> mark() async {
    final s = state;
    if (s == null) return;
    state = s.copyWith(marks: s.marks + 1);
    await _db.addEvent(s.id, EventRecord(at: DateTime.now(), kind: EventKind.mark));
  }

  /// Folosit de alerte: se salvează doar dacă există o sesiune în curs.
  Future<void> logAlert(int index) async {
    final s = state;
    if (s == null) return;
    await _db.addEvent(s.id, EventRecord(at: DateTime.now(), kind: EventKind.alert, text: 'indice $index'));
  }

  Future<SessionRecord?> stop() async {
    final s = state;
    if (s == null) return null;
    _timer?.cancel();
    await _flush();
    final record = await _db.finishSession(s.id, at: DateTime.now());
    state = null;
    await ref.read(gloveSourceProvider).send(ControlCommand.stopSession);
    await _wakelock(false);
    ref.invalidate(historyProvider);
    return record;
  }

  Future<void> _wakelock(bool on) async {
    try {
      on ? await WakelockPlus.enable() : await WakelockPlus.disable();
    } catch (_) {
      // Fără ecran ținut aprins (ex. în teste); sesiunea merge oricum.
    }
  }
}

final sessionProvider = NotifierProvider<SessionNotifier, ActiveSession?>(SessionNotifier.new);

// ---- Alerte ----

/// Urmărește indicele și dă alerta: notificare, vibrație pe mănușă, eveniment în sesiune.
class AlertService {
  AlertService(this._ref);

  final Ref _ref;
  final _monitor = AlertMonitor();
  final _events = StreamController<int>.broadcast();

  /// Indicele la care s-a dat alerta; ecranul principal arată un mesaj.
  Stream<int> get alerts => _events.stream;

  void onLive(LiveState? previous, LiveState next) {
    final p = next.packet;
    if (p == null || next.stale || identical(p, previous?.packet)) return;
    final settings = _ref.read(settingsProvider);
    if (!_monitor.onSample(next.receivedAt!, p.tremorIndex, settings.alertThreshold)) return;
    _events.add(p.tremorIndex);
    _ref.read(notificationsProvider).showAlert(index: p.tremorIndex, threshold: settings.alertThreshold);
    if (settings.vibrateOnAlert) {
      _ref.read(gloveSourceProvider).send(ControlCommand.vibrate, VibrationPattern.alert);
    }
    _ref.read(sessionProvider.notifier).logAlert(p.tremorIndex);
  }

  void dispose() => _events.close();
}

final alertServiceProvider = Provider<AlertService>((ref) {
  final service = AlertService(ref);
  ref.listen<LiveState>(liveProvider, service.onLive);
  // La fiecare conectare, mănușa primește pragul curent (comanda 6).
  ref.listen<AsyncValue<GloveConnection>>(connectionProvider, (prev, next) {
    if (next.value == GloveConnection.connected && prev?.value != GloveConnection.connected) {
      ref.read(gloveSourceProvider).send(ControlCommand.alertThreshold, ref.read(settingsProvider).alertThreshold);
    }
  });
  ref.onDispose(service.dispose);
  return service;
});
