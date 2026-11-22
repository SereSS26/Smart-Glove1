import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manusa_app/app.dart';
import 'package:manusa_app/auth/auth.dart';
import 'package:manusa_app/data/db/app_database.dart';
import 'package:manusa_app/state/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('conturile demo', () {
    late HardcodedAuth auth;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      auth = HardcodedAuth(await SharedPreferences.getInstance());
    });

    test('pacientul intră cu parola corectă și e ținut minte', () async {
      final u = await auth.signIn(' Pacient@Manusa.ro ', 'pacient123');
      expect(u.role, UserRole.patient);
      expect(u.initials, 'IP');
      expect(u.shortName, 'Ion');
      expect(auth.restore()?.id, 'p-ion');
    });

    test('medicul are rolul de medic', () async {
      final u = await auth.signIn('medic@manusa.ro', 'medic123');
      expect(u.isDoctor, isTrue);
      expect(u.initials, 'AP');
      expect(u.shortName, 'Dr. Pavel');
    });

    test('parola greșită dă un mesaj clar', () async {
      await expectLater(
        auth.signIn('pacient@manusa.ro', 'gresit'),
        throwsA(isA<AuthException>().having((e) => e.message, 'mesaj', 'E-mailul sau parola nu se potrivesc.')),
      );
      expect(auth.restore(), isNull);
    });

    test('fără „Ține-mă minte” și după ieșire, nu rămâne nimic salvat', () async {
      await auth.signIn('pacient@manusa.ro', 'pacient123', remember: false);
      expect(auth.restore(), isNull);
      await auth.signIn('pacient@manusa.ro', 'pacient123');
      await auth.signOut();
      expect(auth.restore(), isNull);
    });
  });

  group('ecranele', () {
    setUpAll(() async {
      sqfliteFfiInit();
      final loader = FontLoader('Atkinson');
      for (final w in ['Regular', 'Medium', 'Bold', 'ExtraBold']) {
        loader.addFont(rootBundle.load('assets/fonts/AtkinsonHyperlegibleNext-$w.ttf'));
      }
      await loader.load();
    });

    Future<void> pump(WidgetTester tester, Map<String, Object> prefs, {double textScale = 1}) async {
      SharedPreferences.setMockInitialValues({'dataSource': 0, 'onboardingDone': true, ...prefs});
      final p = await SharedPreferences.getInstance();
      final db = await tester.runAsync(() => AppDatabase.open(inMemoryDatabasePath, factory: databaseFactoryFfi));
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(() {
        tester.view.reset();
        tester.platformDispatcher.clearAllTestValues();
      });
      await tester.pumpWidget(
        ProviderScope(overrides: [prefsProvider.overrideWithValue(p), databaseProvider.overrideWithValue(db!)], child: const ManusaApp()),
      );
      await tester.pump(const Duration(seconds: 1));
    }

    for (final scale in [1.0, 1.3]) {
      testWidgets('fără cont apare autentificarea, iar contul demo de pacient intră (text ${(scale * 100).round()} %)', (tester) async {
        await pump(tester, {}, textScale: scale);
        expect(find.text('Bine ai venit'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('Pacient'));
        await tester.pump(const Duration(seconds: 1));
        // Interogările bazei rulează în timp real: le lăsăm să se termine.
        for (var i = 0; i < 5; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(find.text('Bună, Ion'), findsOneWidget);
        expect(find.text('Remindere'), findsWidgets);
        expect(tester.takeException(), isNull);
        // Închide aplicația, ca mănușa simulată să-și oprească ceasurile înainte de finalul testului.
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      });
    }

    testWidgets('parola greșită arată mesajul sub câmpuri', (tester) async {
      await pump(tester, {});
      await tester.enterText(find.byType(TextField).first, 'pacient@manusa.ro');
      await tester.enterText(find.byType(TextField).last, 'nu');
      await tester.tap(find.text('Intră'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('E-mailul sau parola nu se potrivesc.'), findsOneWidget);
    });

    for (final b in [Brightness.light, Brightness.dark]) {
      testWidgets('medicul vede aplicația lui, cu 3 file (${b.name})', (tester) async {
        await pump(tester, {'authUserId': 'd-pavel', 'themeMode': b == Brightness.dark ? 2 : 1});
        expect(find.text('Pacienți'), findsWidgets);
        Future<void> settle() async {
          for (var i = 0; i < 8; i++) {
            await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
            await tester.pump(const Duration(milliseconds: 100));
          }
        }

        await settle();
        for (final tab in ['Rapoarte', 'Setări', 'Pacienți']) {
          await tester.tap(find.text(tab).last);
          await tester.pump(const Duration(milliseconds: 400));
          await settle();
          expect(tester.takeException(), isNull, reason: tab);
        }
        expect(find.text('Live'), findsNothing);
        await tester.pumpWidget(const SizedBox());
        await settle();
      });
    }
  });
}
