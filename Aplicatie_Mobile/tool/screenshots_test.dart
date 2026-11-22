// ignore_for_file: invalid_use_of_visible_for_testing_member
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manusa_app/app.dart';
import 'package:manusa_app/core/tests.dart';
import 'package:manusa_app/data/db/app_database.dart';
import 'package:manusa_app/data/demo_seed.dart';
import 'package:manusa_app/data/prescription_parser.dart';
import 'package:manusa_app/features/medications/review_medications_screen.dart';
import 'package:manusa_app/features/medications/scan_screen.dart';
import 'package:manusa_app/features/tests/test_picker_screen.dart';
import 'package:manusa_app/features/tests/test_runner_screen.dart';
import 'package:manusa_app/state/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Capturi ale tuturor ecranelor, pe ambele teme, pentru verificarea aspectului (Etapa 9).
/// Nu rulează cu `flutter test`; se pornește manual și scrie PNG-urile în `screenshots/`:
///   flutter test tool/screenshots_test.dart
void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    final atkinson = FontLoader('Atkinson');
    for (final w in ['Regular', 'Medium', 'Bold', 'ExtraBold']) {
      atkinson.addFont(rootBundle.load('assets/fonts/AtkinsonHyperlegibleNext-$w.ttf'));
    }
    await atkinson.load();
    // Iconițele (fără ele, în capturi apar pătrate).
    for (final f in ['MaterialSymbolsRounded', 'MaterialSymbolsOutlined', 'MaterialSymbolsSharp']) {
      try {
        final l = FontLoader('packages/material_symbols_icons/$f')..addFont(rootBundle.load('packages/material_symbols_icons/lib/fonts/$f.ttf'));
        await l.load();
      } catch (_) {}
    }
    try {
      final m = FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await m.load();
    } catch (_) {}
  });

  final boundary = GlobalKey();

  Future<void> settle(WidgetTester tester, [int rounds = 10]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pump(const Duration(milliseconds: 120));
    }
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await settle(tester, 4);
    final ro = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final bytes = await tester.runAsync(() async {
      final image = await ro.toImage(pixelRatio: 1.5);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    });
    File('screenshots/$name.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!);
  }

  Future<AppDatabase> app(WidgetTester tester, {required Brightness b, required String user}) async {
    SharedPreferences.setMockInitialValues({
      'dataSource': 0,
      'onboardingDone': true,
      'authUserId': user,
      'themeMode': b == Brightness.dark ? 2 : 1,
      'rem.exactAsked': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final db = await tester.runAsync(() async {
      final db = await AppDatabase.open(inMemoryDatabasePath, factory: databaseFactoryFfi);
      await addDemoMonths(db, threshold: 60, days: 40);
      return db;
    });
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: ProviderScope(
          overrides: [prefsProvider.overrideWithValue(prefs), databaseProvider.overrideWithValue(db!)],
          child: const ManusaApp(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await settle(tester);
    return db;
  }

  NavigatorState nav(WidgetTester tester) => tester.state<NavigatorState>(find.byType(Navigator).first);

  Future<void> close(WidgetTester tester, AppDatabase db) async {
    await tester.pumpWidget(const SizedBox());
    await settle(tester, 3);
    await tester.runAsync(db.close);
  }

  for (final b in Brightness.values) {
    final t = b.name;

    testWidgets('pacient ($t)', (tester) async {
      final db = await app(tester, b: b, user: 'p-ion');
      await shot(tester, '${t}_01_live');
      for (final (tab, name) in [('Istoric', '02_istoric'), ('Remindere', '03_remindere'), ('Setări', '04_setari')]) {
        await tester.tap(find.text(tab).last);
        await settle(tester);
        await shot(tester, '${t}_$name');
      }
      nav(tester).push(MaterialPageRoute<void>(builder: (_) => const TestPickerScreen()));
      await settle(tester);
      await shot(tester, '${t}_05_alege_testul');
      nav(tester).pushReplacement(MaterialPageRoute<void>(builder: (_) => const TestRunnerScreen(tests: TestKind.assessment)));
      await settle(tester);
      await shot(tester, '${t}_06_test_pas');
      nav(tester).pushReplacement(MaterialPageRoute<void>(builder: (_) => const ScanScreen()));
      await settle(tester);
      await shot(tester, '${t}_07_scaneaza');
      nav(tester).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ReviewMedicationsScreen(found: parsePrescription('Madopar 250 mg 1-1-1 (100)\nRivotril 0,5 mg ½ cp la culcare')),
        ),
      );
      await settle(tester);
      await shot(tester, '${t}_08_verifica_medicamentele');
      await close(tester, db);
    });

    testWidgets('medic ($t)', (tester) async {
      final db = await app(tester, b: b, user: 'd-pavel');
      await shot(tester, '${t}_10_pacienti');
      await tester.scrollUntilVisible(find.text('Maria Ionescu, 72 ani'), 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Maria Ionescu, 72 ani'));
      await settle(tester);
      await shot(tester, '${t}_11_pacient');
      nav(tester).pop();
      await settle(tester);
      for (final (tab, name) in [('Rapoarte', '12_rapoarte'), ('Setări', '13_setari_medic')]) {
        await tester.tap(find.text(tab).last);
        await settle(tester);
        await shot(tester, '${t}_$name');
      }
      await close(tester, db);
    });
  }

  testWidgets('autentificare', (tester) async {
    SharedPreferences.setMockInitialValues({'themeMode': 1});
    final prefs = await SharedPreferences.getInstance();
    final db = await tester.runAsync(() => AppDatabase.open(inMemoryDatabasePath, factory: databaseFactoryFfi));
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      RepaintBoundary(
        key: boundary,
        child: ProviderScope(
          overrides: [prefsProvider.overrideWithValue(prefs), databaseProvider.overrideWithValue(db!)],
          child: const ManusaApp(),
        ),
      ),
    );
    await settle(tester);
    await shot(tester, 'light_00_autentificare');
    await close(tester, db);
  });
}
