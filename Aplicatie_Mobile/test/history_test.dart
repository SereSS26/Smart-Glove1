import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manusa_app/core/contract.dart';
import 'package:manusa_app/data/db/app_database.dart';
import 'package:manusa_app/data/db/models.dart';
import 'package:manusa_app/data/demo_seed.dart';
import 'package:manusa_app/features/history/history_screen.dart';
import 'package:manusa_app/services/history_stats.dart';
import 'package:manusa_app/state/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

SampleRecord _s(DateTime at, int index) => SampleRecord(
  at: at,
  frequency: 4.8,
  rms: index * 0.3,
  index: index,
  state: HandState.rest,
  fingers: const [null, null, null, null, null],
);

void main() {
  sqfliteFfiInit();
  final now = DateTime(2026, 11, 21, 15, 30); // sâmbătă

  group('perioadele', () {
    test('săptămâna începe lunea, luna e luna calendaristică', () {
      final w = rangeFor(Period.week, 0, now);
      expect(w.start, DateTime(2026, 11, 16));
      expect(w.end, DateTime(2026, 11, 23));
      expect(w.label, '16 – 22 noiembrie');
      expect(rangeFor(Period.week, 1, now).label, '9 – 15 noiembrie');
      final m = rangeFor(Period.month, 0, now);
      expect(m.days, 30);
      expect(m.label, 'Noiembrie 2026');
      expect(rangeFor(Period.month, 1, now).label, 'Octombrie 2026');
      expect(rangeFor(Period.day, 0, now).label, 'Azi · 21 noiembrie');
      expect(rangeFor(Period.day, 1, now).label, 'Ieri · 20 noiembrie');
    });

    test('procentul față de perioada trecută și timpul peste prag', () {
      final range = rangeFor(Period.week, 0, now);
      final samples = [for (var i = 0; i < 100; i++) _s(DateTime(2026, 11, 17, 9, 0, i), i < 20 ? 70 : 40)];
      final previous = [for (var i = 0; i < 100; i++) _s(DateTime(2026, 11, 10, 9, 0, i), 55)];
      final st = computeStats(
        period: Period.week,
        range: range,
        samples: samples,
        previous: previous,
        sessions: const [],
        threshold: 60,
        now: now,
      );
      expect(st.mean, closeTo(46, 0.01));
      expect(st.deltaPercent, -16); // (46 − 55) / 55
      expect(st.overThreshold, closeTo(20, 0.01));
      expect(st.peak, 70);
      expect(st.bars, hasLength(7));
      expect(st.bars[1].value, closeTo(46, 0.01)); // marți
      expect(st.bars[5].highlight, isTrue); // sâmbătă = azi
    });

    test('calendarul lunii: noiembrie 2026 începe duminică', () {
      final range = rangeFor(Period.month, 0, now);
      final st = computeStats(
        period: Period.month,
        range: range,
        samples: [_s(DateTime(2026, 11, 3, 10), 30)],
        previous: const [],
        sessions: const [],
        threshold: 60,
        now: now,
      );
      expect(st.leadingBlanks, 6);
      expect(st.cells, hasLength(30));
      expect(st.cells[2].value, 30);
      expect(st.cells[20].today, isTrue);
      expect(st.cells[25].future, isTrue);
      expect(st.deltaPercent, isNull);
    });

    test('dimineața față de seară', () {
      final s = [
        for (var i = 0; i < 10; i++) _s(DateTime(2026, 11, 20, 9, i), 40),
        for (var i = 0; i < 10; i++) _s(DateTime(2026, 11, 20, 20, i), 50),
      ];
      expect(morningEveningInsight(s), 'Seara, tremorul e cu 25 % mai mare decât dimineața.');
    });
  });

  testWidgets('Istoricul se desenează pe zi, săptămână și lună, cu 3 luni de date demo', (tester) async {
    final loader = FontLoader('Atkinson');
    for (final w in ['Regular', 'Medium', 'Bold', 'ExtraBold']) {
      loader.addFont(rootBundle.load('assets/fonts/AtkinsonHyperlegibleNext-$w.ttf'));
    }
    await loader.load();
    SharedPreferences.setMockInitialValues({'dataSource': 0});
    final prefs = await SharedPreferences.getInstance();
    final db = await tester.runAsync(() async {
      final db = await AppDatabase.open(inMemoryDatabasePath, factory: databaseFactoryFfi);
      final n = await addDemoMonths(db, threshold: 60, days: 40);
      expect(n, greaterThan(60));
      return db;
    });
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearAllTestValues();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [prefsProvider.overrideWithValue(prefs), databaseProvider.overrideWithValue(db!)],
        child: const MaterialApp(home: Scaffold(body: HistoryScreen())),
      ),
    );
    for (var i = 0; i < 20 && find.text('Media indicelui').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Media indicelui'), findsOneWidget);
    expect(tester.takeException(), isNull);
    for (final p in ['Lună', 'Zi', 'Săptămână']) {
      await tester.tap(find.text(p));
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull, reason: p);
    }
    expect(find.text('Luna dintr-o privire'), findsNothing);
    await tester.tap(find.byTooltip('Perioada anterioară'));
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Înapoi la azi'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
