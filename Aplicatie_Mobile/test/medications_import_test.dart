import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manusa_app/data/db/app_database.dart';
import 'package:manusa_app/data/medication_repository.dart';
import 'package:manusa_app/features/medications/import_text_screen.dart';
import 'package:manusa_app/features/medications/review_medications_screen.dart';
import 'package:manusa_app/features/medications/scan_screen.dart';
import 'package:manusa_app/state/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _reteta = '''
Pacient: Ion Popescu
Rp./
1. Madopar   1-1-1   (100)
2. Rivotril 0,5 mg  ½ cp la culcare
''';

Future<void> _settle(WidgetTester tester, [int rounds = 8]) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  sqfliteFfiInit();

  setUpAll(() async {
    final loader = FontLoader('Atkinson');
    for (final w in ['Regular', 'Medium', 'Bold', 'ExtraBold']) {
      loader.addFont(rootBundle.load('assets/fonts/AtkinsonHyperlegibleNext-$w.ttf'));
    }
    await loader.load();
  });

  Future<AppDatabase> pump(WidgetTester tester, Widget home, {double scale = 1.3}) async {
    SharedPreferences.setMockInitialValues({'rem.exactAsked': true});
    final prefs = await SharedPreferences.getInstance();
    final db = await tester.runAsync(() => AppDatabase.open(inMemoryDatabasePath, factory: databaseFactoryFfi));
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
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
    await tester.pump();
    return db;
  }

  testWidgets('poza rețetei → verificare cu semne pentru ce e nesigur → salvare', (tester) async {
    final db = await pump(tester, ScanScreen(imagePath: '/tmp/reteta.jpg', reader: (_) async => _reteta));
    await _settle(tester);
    expect(find.text('Am găsit 2 medicamente'), findsOneWidget);
    expect(find.textContaining('Aplicația poate citi greșit'), findsOneWidget);
    expect(find.byTooltip('Citit nesigur: verifică cu rețeta'), findsWidgets);
    expect(tester.takeException(), isNull);

    // Debifăm Madopar (primul card) și salvăm doar Rivotril.
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    expect(find.text('Nu îl adaug'), findsOneWidget);
    final list = find.descendant(of: find.byType(ReviewMedicationsScreen), matching: find.byType(Scrollable)).first;
    await tester.scrollUntilVisible(find.text('Salvează medicamentul'), 500, scrollable: list);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvează medicamentul'));
    await _settle(tester);
    final meds = await tester.runAsync(() => MedicationRepository(db.raw).medications());
    expect(meds!.map((m) => m.title), ['Rivotril 0,5 mg']);
    expect(meds.single.times, ['22:00']);
    expect(meds.single.dose, 0.5);
    expect(meds.single.stock, 30, reason: 'fără cantitate pe rețetă: o cutie de 30, marcată de verificat');
    expect(tester.takeException(), isNull);
    await tester.runAsync(db.close);
  });

  testWidgets('textul fără medicamente rămâne de corectat; cu medicamente duce la verificare', (tester) async {
    final db = await pump(tester, const ImportTextScreen());
    await tester.enterText(find.byType(TextField), 'Bună ziua, ne vedem joi.');
    await tester.pump();
    await tester.tap(find.text('Caută medicamentele'));
    await tester.pump();
    expect(find.textContaining('Nu am găsit niciun medicament'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Propranolol 40 mg 1-0-1, 60 cp');
    await tester.pump();
    await tester.tap(find.text('Caută medicamentele'));
    await tester.pumpAndSettle();
    expect(find.text('Am găsit un medicament'), findsOneWidget);
    expect(find.text('Propranolol'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.runAsync(db.close);
  });

  testWidgets('ecranul de scanare se desenează la text 130 %', (tester) async {
    final db = await pump(tester, const ScanScreen());
    expect(find.text('Fă o poză'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.runAsync(db.close);
  });
}
