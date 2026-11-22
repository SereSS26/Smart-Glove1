import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manusa_app/core/contract.dart';
import 'package:manusa_app/data/clinic_repository.dart';
import 'package:manusa_app/data/db/app_database.dart';
import 'package:manusa_app/data/db/models.dart';
import 'package:manusa_app/data/demo_clinic.dart';
import 'package:manusa_app/features/doctor/patients_screen.dart';
import 'package:manusa_app/features/doctor/reports_screen.dart';
import 'package:manusa_app/features/doctor/weekly_summary.dart';
import 'package:manusa_app/services/history_stats.dart';
import 'package:manusa_app/services/report_service.dart';
import 'package:manusa_app/state/clinic_providers.dart';
import 'package:manusa_app/state/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> _settle(WidgetTester tester, [int rounds = 10]) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

SampleRecord _s(DateTime at, int i) =>
    SampleRecord(at: at, frequency: 4.8, rms: 1, index: i, state: HandState.rest, fingers: const [null, null, null, null, null]);

void main() {
  sqfliteFfiInit();
  final now = DateTime(2026, 11, 21, 15, 0);

  test('pe 7, 30 și 90 de zile: bare pe zile sau pe săptămâni, calendarul ultimelor zile', () {
    final samples = [for (var d = 0; d < 90; d++) _s(DateTime(2026, 11, 21 - d, 9), 40)];
    for (final (days, bars, cells) in [(7, 7, 7), (30, 30, 30), (90, 13, 35)]) {
      final st = rollingStats(days: days, samples: samples, previous: const [], sessions: const [], threshold: 60, now: now);
      expect(st.bars, hasLength(bars), reason: '$days zile');
      expect(st.cells, hasLength(cells), reason: '$days zile');
      expect(st.mean, 40);
    }
    expect(dailyMeans(samples, days: 3, now: now), [40, 40, 40]);
  });

  test('clinica demo: fiecare pacient de urmărit are motivul lui; Ion vine din baza locală', () async {
    final db = await AppDatabase.open(inMemoryDatabasePath, factory: databaseFactoryFfi);
    final clinic = DemoClinic(db, clock: () => now);
    final from = DateTime(2026, 11, 1);
    final to = DateTime(2026, 11, 22);
    final byName = <String, PatientSummary>{};
    for (final p in await clinic.patients()) {
      byName[p.name] = summarize(
        await clinic.record(p.id, from: from, to: to),
        now: now,
      );
    }
    expect(byName.keys, containsAll(['Maria Ionescu', 'Gheorghe Dumitru', 'Vasile Marin', 'Elena Stan', 'Ion Popescu']));
    expect(byName['Maria Ionescu']!.reasons.join(), contains('tremor în creștere'));
    expect(byName['Gheorghe Dumitru']!.reasons.join(), contains('aderență'));
    expect(byName['Vasile Marin']!.reasons, contains('fără date de 4 zile'));
    expect(byName['Elena Stan']!.needsAttention, isFalse);
    expect(byName['Ion Popescu']!.reasons, contains('fără date încă'));

    // O sesiune înregistrată ca pacient apare imediat la medic.
    final id = await db.startSession(at: DateTime(2026, 11, 21, 10), activity: HandState.rest, simulated: false);
    await db.addSamples(id, [for (var i = 0; i < 120; i++) _s(DateTime(2026, 11, 21, 10, 0, i), 48)]);
    await db.finishSession(id, at: DateTime(2026, 11, 21, 10, 2));
    final ion = await clinic.record(AppDatabase.localPatient, from: from, to: to);
    expect(ion.sessions, hasLength(1));
    expect(summarize(ion, now: now).mean7, 48);

    // Aceleași date la fiecare pornire.
    final again = summarize(
      await DemoClinic(db, clock: () => now).record('p-maria', from: from, to: to),
      now: now,
    );
    expect(again.mean7, byName['Maria Ionescu']!.mean7);
    await db.close();
  });

  test('rezumatul săptămânal și CSV-ul pe zile', () {
    const a = ClinicPatient(id: 'a', name: 'Maria Ionescu', age: 72, diagnosis: 'x');
    const b = ClinicPatient(id: 'b', name: 'Elena Stan', age: 59, diagnosis: 'y');
    PatientSummary sum(ClinicPatient p, List<String> reasons) => PatientSummary(
      patient: p,
      daily: const [],
      mean7: 40,
      delta7: 0,
      alertsToday: 0,
      adherence7: null,
      lastData: null,
      reasons: reasons,
    );
    expect(
      weeklySummaryText([
        sum(a, ['tremor în creștere: +20 % în 7 zile']),
        sum(b, []),
      ]),
      '2 pacienți · 1 de urmărit: Maria Ionescu (tremor în creștere: +20 % în 7 zile).',
    );
    expect(weeklySummaryText([sum(b, [])]), '1 pacient · niciunul de urmărit.');

    final csv = dailyCsv(
      samples: [_s(DateTime(2026, 11, 20, 9), 50), _s(DateTime(2026, 11, 20, 9, 1), 70)],
      sessions: const [],
      dosesByDay: {DateTime(2026, 11, 20): 3},
      from: DateTime(2026, 11, 20),
      to: DateTime(2026, 11, 22),
      threshold: 60,
    );
    expect(csv.split('\n'), [
      'Data;Media indicelui;Maxim;Peste prag (60) %;Sesiuni;Doze luate',
      '2026-11-20;60,0;70;50,0;0;3',
      '2026-11-21;;;;0;0',
      '',
    ]);
  });

  testWidgets('medicul: lista, detaliul pe toate filele și rapoartele, la text 130 %', (tester) async {
    final loader = FontLoader('Atkinson');
    for (final w in ['Regular', 'Medium', 'Bold', 'ExtraBold']) {
      loader.addFont(rootBundle.load('assets/fonts/AtkinsonHyperlegibleNext-$w.ttf'));
    }
    await loader.load();
    SharedPreferences.setMockInitialValues({'authUserId': 'd-pavel'});
    final prefs = await SharedPreferences.getInstance();
    final db = await tester.runAsync(() => AppDatabase.open(inMemoryDatabasePath, factory: databaseFactoryFfi));
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearAllTestValues();
    });
    Widget app(Widget home) => ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db!),
        clinicProvider.overrideWithValue(DemoClinic(db)),
      ],
      child: MaterialApp(home: Scaffold(body: home)),
    );

    await tester.pumpWidget(app(const PatientsScreen()));
    await _settle(tester);
    expect(find.text('NECESITĂ ATENȚIE'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Maria Ionescu, 72 ani'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Maria Ionescu, 72 ani'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Maria Ionescu, 72 ani'));
    await _settle(tester);
    expect(find.text('Media indicelui'), findsOneWidget);
    for (final tab in ['Sesiuni', 'Medicație', '90 zile', 'Prezentare', '7 zile']) {
      await tester.tap(find.text(tab).first);
      await _settle(tester, 6);
      expect(tester.takeException(), isNull, reason: tab);
    }
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await _settle(tester, 4);
    await tester.scrollUntilVisible(find.byType(TextField), -300, scrollable: find.byType(Scrollable).first);

    await tester.enterText(find.byType(TextField), 'elena');
    await tester.pump();
    expect(find.text('Elena Stan, 59 ani'), findsOneWidget);
    expect(find.text('Maria Ionescu, 72 ani'), findsNothing);

    await tester.pumpWidget(app(const ReportsScreen()));
    await _settle(tester);
    expect(find.text('Toți pacienții'), findsOneWidget);
    await tester.tap(find.text('Toți pacienții'));
    await tester.pump();
    await tester.scrollUntilVisible(find.text('Generează și trimite (5)'), 400, scrollable: find.byType(Scrollable).first);
    expect(find.text('Generează și trimite (5)'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db!.close);
  });

  testWidgets('pe tabletă: lista în stânga, detaliul în dreapta', (tester) async {
    SharedPreferences.setMockInitialValues({'authUserId': 'd-pavel'});
    final prefs = await SharedPreferences.getInstance();
    final db = await tester.runAsync(() => AppDatabase.open(inMemoryDatabasePath, factory: databaseFactoryFfi));
    tester.view.physicalSize = const Size(2560, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          prefsProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(db!),
          clinicProvider.overrideWithValue(DemoClinic(db)),
        ],
        child: const MaterialApp(home: Scaffold(body: PatientsScreen())),
      ),
    );
    await _settle(tester);
    expect(find.textContaining('Alege un pacient din listă'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Elena Stan, 59 ani'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Elena Stan, 59 ani'));
    await _settle(tester);
    expect(find.text('Media indicelui'), findsOneWidget);
    expect(find.text('Elena Stan'), findsOneWidget);
    expect(find.byTooltip('Exportă'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
  });
}
