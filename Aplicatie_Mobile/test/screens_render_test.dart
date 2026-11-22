import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manusa_app/app.dart';
import 'package:manusa_app/core/theme.dart';
import 'package:manusa_app/data/db/app_database.dart';
import 'package:manusa_app/features/calibrate/calibrate_screen.dart';
import 'package:manusa_app/features/connect/connect_screen.dart';
import 'package:manusa_app/features/settings/info_screens.dart';
import 'package:manusa_app/state/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Lasă interogările bazei (care rulează în timp real, nu în timpul simulat al testului) să se termine.
Future<void> settleDb(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Ecranul principal se desenează fără erori pe ambele teme și cu textul mărit la 130 %.
void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    // Fontul real al aplicației; fără el, testul folosește un font de test mai lat și raportează depășiri false.
    final loader = FontLoader('Atkinson');
    for (final w in ['Regular', 'Medium', 'Bold', 'ExtraBold']) {
      loader.addFont(rootBundle.load('assets/fonts/AtkinsonHyperlegibleNext-$w.ttf'));
    }
    await loader.load();
  });

  Future<void> pumpApp(WidgetTester tester, {required Brightness brightness, double textScale = 1}) async {
    SharedPreferences.setMockInitialValues({
      'dataSource': 0,
      'onboardingDone': true,
      'authUserId': 'p-ion',
      'themeMode': brightness == Brightness.dark ? 2 : 1,
    });
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
      ProviderScope(overrides: [prefsProvider.overrideWithValue(prefs), databaseProvider.overrideWithValue(db!)], child: const ManusaApp()),
    );
    // Simulatorul se conectează în 0,4 s, apoi trimite pachete.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await settleDb(tester);
  }

  for (final b in Brightness.values) {
    testWidgets('Live se desenează pe tema ${b.name}', (tester) async {
      await pumpApp(tester, brightness: b);
      expect(tester.takeException(), isNull);
      expect(find.text('Pornește o sesiune'), findsOneWidget);
      expect(find.text('Degete'.toUpperCase()), findsOneWidget);
      expect(Theme.of(tester.element(find.byType(Scaffold).first)).brightness, b);
      expect(AppColors.background, b == Brightness.dark ? AppPalette.dark.background : AppPalette.light.background);
      await tester.tap(find.text('Istoric').last);
      await tester.pump(const Duration(milliseconds: 500));
      await settleDb(tester);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Live cu text mărit la 130 % nu are erori de așezare', (tester) async {
    await pumpApp(tester, brightness: Brightness.light, textScale: 1.3);
    expect(tester.takeException(), isNull);
    expect(find.text('Pornește o sesiune'), findsOneWidget);
  });

  // Fiecare ecran, deschis peste cel principal, pe ambele teme și cu text mărit.
  final screens = <String, Widget Function()>{
    'Calibrare': () => const CalibrateScreen(),
    'Conectare': () => const ConnectScreen(),
    'Instrucțiuni': () => const InstructionsScreen(),
    'Despre': () => const AboutScreen(),
  };
  for (final b in Brightness.values) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('toate ecranele se desenează (${b.name}, text ${(scale * 100).round()} %)', (tester) async {
        await pumpApp(tester, brightness: b, textScale: scale);
        for (final tab in ['Istoric', 'Remindere', 'Setări', 'Live']) {
          await tester.tap(find.text(tab).last);
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull, reason: tab);
        }
        final navigator = tester.state<NavigatorState>(find.byType(Navigator).first);
        for (final entry in screens.entries) {
          navigator.push(MaterialPageRoute<void>(builder: (_) => entry.value()));
          await tester.pump(const Duration(milliseconds: 600));
          expect(tester.takeException(), isNull, reason: entry.key);
          navigator.pop();
          await tester.pump(const Duration(milliseconds: 600));
        }
        // Sesiunea: pornită din Live.
        await tester.ensureVisible(find.text('Pornește o sesiune'));
        await tester.pump();
        await tester.tap(find.text('Pornește o sesiune'));
        await tester.pump(const Duration(milliseconds: 600));
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('Ce verificăm azi?'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'Alegerea testului');
        await tester.scrollUntilVisible(find.text('Înregistrare liberă'), 200, scrollable: find.byType(Scrollable).last);
        await tester.pump();
        await tester.tap(find.text('Înregistrare liberă'));
        // Baza de date lucrează asincron real; îi lăsăm timp în afara ceasului simulat.
        for (var i = 0; i < 15 && find.text('Oprește sesiunea').evaluate().isEmpty; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
          await tester.pump(const Duration(milliseconds: 200));
        }
        expect(find.text('Oprește sesiunea'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'Sesiune');
      });
    }
  }

  testWidgets('prima pornire se desenează cu text mărit', (tester) async {
    SharedPreferences.setMockInitialValues({'authUserId': 'p-ion'});
    final prefs = await SharedPreferences.getInstance();
    final db = await tester.runAsync(() => AppDatabase.open(inMemoryDatabasePath, factory: databaseFactoryFfi));
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearAllTestValues();
    });
    await tester.pumpWidget(
      ProviderScope(overrides: [prefsProvider.overrideWithValue(prefs), databaseProvider.overrideWithValue(db!)], child: const ManusaApp()),
    );
    await tester.pump();
    expect(find.text('Bun venit'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
