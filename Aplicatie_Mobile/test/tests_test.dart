import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manusa_app/core/contract.dart';
import 'package:manusa_app/core/tests.dart';
import 'package:manusa_app/data/db/app_database.dart';
import 'package:manusa_app/data/db/models.dart';
import 'package:manusa_app/features/tests/test_picker_screen.dart';
import 'package:manusa_app/features/tests/test_runner_screen.dart';
import 'package:manusa_app/services/tapping.dart';
import 'package:manusa_app/state/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  group('analiza tapping-ului', () {
    List<double> wave(double hz, double seconds, {double amp = 40, double fade = 0, int seed = 1}) {
      final r = Random(seed);
      return [
        for (var i = 0; i < (seconds * 10).round(); i++)
          50 + amp * (1 - fade * i / (seconds * 10)) * sin(2 * pi * hz * i / 10) + (r.nextDouble() - 0.5) * 4,
      ];
    }

    test('numără corect 2 și 3 atingeri pe secundă', () {
      final two = analyzeTapping(wave(2, 15));
      expect(two.taps, inInclusiveRange(29, 31));
      expect(two.rate, closeTo(2, 0.1));
      final three = analyzeTapping(wave(3, 15));
      expect(three.taps, inInclusiveRange(44, 46));
      expect(three.regularity, lessThan(0.2));
      expect(three.rhythmLabel, 'ritm regulat');
    });

    test('vede oboseala când amplitudinea scade spre final', () {
      final tired = analyzeTapping(wave(2.5, 15, fade: 0.5));
      final fresh = analyzeTapping(wave(2.5, 15));
      expect(tired.fatigue, greaterThan(0.25));
      expect(fresh.fatigue, lessThan(0.1));
    });

    test('tremurul mărunt nu e numărat ca atingeri', () {
      final shaky = [for (var i = 0; i < 150; i++) 50 + 2 * sin(2 * pi * 5 * i / 10)];
      expect(analyzeTapping(shaky).taps, 0);
    });

    test('tapping pe ecran: ritm, precizie, încetinire', () {
      final times = [for (var i = 0; i < 40; i++) i * 0.5];
      final r = analyzeScreenTapping(times, duration: 20, misses: 10);
      expect(r.rate, 2);
      expect(r.amplitude, 80);
      expect(r.regularity, closeTo(0, 1e-9));
    });
  });

  test('baza de date trece de la versiunea 1 la 2 fără să piardă sesiunile', () async {
    final path = '${Directory.systemTemp.path}/manusa_migrare_${DateTime.now().microsecondsSinceEpoch}.db';
    final v1 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE sessions (id INTEGER PRIMARY KEY AUTOINCREMENT, started_at INTEGER NOT NULL, ended_at INTEGER, activity INTEGER NOT NULL, '
            "note TEXT NOT NULL DEFAULT '', avg_freq REAL, avg_index INTEGER NOT NULL DEFAULT 0, max_index INTEGER NOT NULL DEFAULT 0, "
            'alert_count INTEGER NOT NULL DEFAULT 0, simulated INTEGER NOT NULL)',
          );
          await db.execute(
            'CREATE TABLE samples (session_id INTEGER NOT NULL, t INTEGER NOT NULL, freq REAL NOT NULL, rms REAL NOT NULL, idx INTEGER NOT NULL, '
            'state INTEGER NOT NULL, f1 INTEGER, f2 INTEGER, f3 INTEGER, f4 INTEGER, f5 INTEGER)',
          );
          await db.execute(
            "CREATE TABLE events (session_id INTEGER NOT NULL, t INTEGER NOT NULL, kind TEXT NOT NULL, text TEXT NOT NULL DEFAULT '')",
          );
          await db.insert('sessions', {'started_at': 1, 'ended_at': 2, 'activity': 0, 'avg_index': 40, 'simulated': 0});
        },
      ),
    );
    await v1.close();

    final db = await AppDatabase.open(path, factory: databaseFactoryFfi);
    final old = await db.sessions(simulated: false);
    expect(old, hasLength(1));
    expect(old.single.kind, SessionKind.free);
    final id = await db.startSession(
      at: DateTime(2026, 11, 21, 9),
      activity: HandState.rest,
      simulated: false,
      kind: SessionKind.assessment,
    );
    await db.addTestResult(
      id,
      TestResultRecord(
        test: TestKind.tappingGlove.id,
        startedAt: DateTime(2026, 11, 21, 9),
        endedAt: DateTime(2026, 11, 21, 9, 0, 15),
        value: 3.2,
        metrics: const {'taps': 48},
        trace: const [10, 80, 12],
      ),
    );
    await db.finishSession(id, at: DateTime(2026, 11, 21, 9, 3));
    final back = await db.resultsOf(TestKind.tappingGlove.id, simulated: false);
    expect(back.single.value, 3.2);
    expect(back.single.metrics['taps'], 48);
    expect(back.single.trace, [10, 80, 12]);
    expect((await db.session(id))!.kind, SessionKind.assessment);
    await db.close();
  });

  group('ecranele testelor', () {
    setUpAll(() async {
      final loader = FontLoader('Atkinson');
      for (final w in ['Regular', 'Medium', 'Bold', 'ExtraBold']) {
        loader.addFont(rootBundle.load('assets/fonts/AtkinsonHyperlegibleNext-$w.ttf'));
      }
      await loader.load();
    });

    Future<void> pump(WidgetTester tester, Widget home, {double textScale = 1}) async {
      SharedPreferences.setMockInitialValues({'dataSource': 0, 'onboardingDone': true, 'authUserId': 'p-ion'});
      final prefs = await SharedPreferences.getInstance();
      final db = await tester.runAsync(() => AppDatabase.open(inMemoryDatabasePath, factory: databaseFactoryFfi));
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearAllTestValues();
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [prefsProvider.overrideWithValue(prefs), databaseProvider.overrideWithValue(db!)],
          child: MaterialApp(home: home),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
    }

    for (final scale in [1.0, 1.3]) {
      testWidgets('alegerea testului se desenează (text ${(scale * 100).round()} %)', (tester) async {
        await pump(tester, const TestPickerScreen(), textScale: scale);
        expect(find.text('Ce verificăm azi?'), findsOneWidget);
        await tester.scrollUntilVisible(find.text('Tremor în mișcare'), 200, scrollable: find.byType(Scrollable).first);
        expect(find.text('Tremor în mișcare'), findsOneWidget);
        expect(find.textContaining('Deget'), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('testul de tapping pe ecran merge cap-coadă (text ${(scale * 100).round()} %)', (tester) async {
        await pump(tester, const TestRunnerScreen(tests: [TestKind.tappingScreen]), textScale: scale);
        expect(find.text('Tapping pe ecran'), findsOneWidget);
        await tester.ensureVisible(find.text('Încep'));
        await tester.pump();
        await tester.tap(find.text('Încep'));
        await tester.pump(const Duration(seconds: 4));
        expect(find.textContaining('atingeri:'), findsOneWidget);
        // Atinge alternativ cercurile câteva secunde.
        for (var i = 0; i < 10; i++) {
          await tester.tap(find.bySemanticsLabel(i.isEven ? 'Cercul din stânga' : 'Cercul din dreapta'));
          await tester.pump(const Duration(milliseconds: 300));
        }
        await tester.pump(const Duration(seconds: 20));
        await tester.ensureVisible(find.text('atingeri pe secundă'));
        expect(find.text('atingeri pe secundă'), findsOneWidget);
        expect(find.text('Vezi rezultatul'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
