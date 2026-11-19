import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manusa_app/core/contract.dart';
import 'package:manusa_app/core/live_packet.dart';
import 'package:manusa_app/data/db/app_database.dart';
import 'package:manusa_app/data/db/models.dart';
import 'package:manusa_app/state/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({'dataSource': 0, 'alertThreshold': 60});
    db = await AppDatabase.open(inMemoryDatabasePath, factory: databaseFactoryFfi);
    container = ProviderContainer(
      overrides: [prefsProvider.overrideWithValue(await SharedPreferences.getInstance()), databaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  LivePacket packet(int index) => LivePacket(
    fingers: const [10, 20, 30, 40, 50],
    frequencyHz: 4.8,
    rmsDps: index * 0.3,
    tremorIndex: index,
    state: HandState.rest,
    batteryPercent: null,
    flags: 3,
  );

  test('momentul marcat și nota se salvează ca evenimente ale sesiunii', () async {
    final session = container.read(sessionProvider.notifier);
    await session.start();
    await session.mark();
    await session.addNote('am luat medicamentul');
    final record = await session.stop();

    final events = await db.events(record!.id);
    expect(events.map((e) => e.kind), containsAll([EventKind.mark, EventKind.note]));
    expect(record.note, 'am luat medicamentul');
    expect(container.read(sessionProvider), isNull);
  });

  test('alerta după 5 s peste prag: mesaj în aplicație și eveniment în sesiune', () async {
    final alerts = container.read(alertServiceProvider);
    final emitted = <int>[];
    final sub = alerts.alerts.listen(emitted.add);
    final session = container.read(sessionProvider.notifier);
    await session.start();

    final t0 = DateTime(2026, 11, 19, 9);
    LiveState? previous;
    for (var i = 0; i <= 60; i++) {
      // 6 secunde de pachete la 10 Hz, indice 72 (peste pragul 60).
      final next = LiveState(
        packet: packet(72),
        receivedAt: t0.add(Duration(milliseconds: i * 100)),
        stale: false,
      );
      alerts.onLive(previous, next);
      previous = next;
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(emitted, [72]);

    final record = await session.stop();
    expect(record!.alertCount, 1);
    await sub.cancel();
  });

  test('datele vechi nu declanșează alerte', () async {
    final alerts = container.read(alertServiceProvider);
    final emitted = <int>[];
    final sub = alerts.alerts.listen(emitted.add);
    final t0 = DateTime(2026, 11, 19, 9);
    for (var i = 0; i <= 60; i++) {
      alerts.onLive(
        null,
        LiveState(
          packet: packet(90),
          receivedAt: t0.add(Duration(milliseconds: i * 100)),
          stale: true,
        ),
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(emitted, isEmpty);
    await sub.cancel();
  });
}
