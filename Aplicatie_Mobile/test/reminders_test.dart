import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manusa_app/core/contract.dart';
import 'package:manusa_app/core/format.dart';
import 'package:manusa_app/data/db/app_database.dart';
import 'package:manusa_app/data/db/models.dart';
import 'package:manusa_app/data/demo_seed.dart';
import 'package:manusa_app/data/medication_repository.dart';
import 'package:manusa_app/data/medications.dart';
import 'package:manusa_app/features/reminders/medication_form.dart';
import 'package:manusa_app/features/reminders/reminder_edit_screen.dart';
import 'package:manusa_app/features/reminders/reminders_screen.dart';
import 'package:manusa_app/state/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Medication _med({
  int id = 1,
  List<String> times = const ['08:00', '14:00', '20:00'],
  double stock = 12,
  double dose = 1,
  DateTime? created,
}) => Medication(
  id: id,
  name: 'Madopar',
  strength: '250 mg',
  dose: dose,
  times: times,
  stock: stock,
  packSize: 100,
  createdAt: created ?? DateTime(2026, 11, 1),
);

Future<void> _loadFont() async {
  final loader = FontLoader('Atkinson');
  for (final w in ['Regular', 'Medium', 'Bold', 'ExtraBold']) {
    loader.addFont(rootBundle.load('assets/fonts/AtkinsonHyperlegibleNext-$w.ttf'));
  }
  await loader.load();
}

Future<void> _settle(WidgetTester tester, [int rounds = 8]) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  sqfliteFfiInit();
  final now = DateTime(2026, 11, 21, 14, 10);

  group('stocul', () {
    test('zilele rămase = stoc ÷ (doză × prize pe zi)', () {
      final m = _med();
      expect(m.dailyUse, 3);
      expect(m.daysLeft, 4);
      expect(m.lowStock, isTrue);
      expect(_med(stock: 60).lowStock, isFalse);
      expect(_med(times: const ['22:00'], dose: 0.5, stock: 28).daysLeft, 56);
      expect(_med(times: const []).daysLeft, isNull);
    });

    test('cantitățile se scriu ca pe rețetă', () {
      expect(Fmt.qty(1), '1');
      expect(Fmt.qty(0.5), '½');
      expect(Fmt.qty(1.5), '1½');
      expect(Fmt.qty(0.25), '¼');
      expect(_med(dose: 0.5).doseLong, '½ comprimat');
      expect(_med(dose: 2).doseLong, '2 comprimate');
      expect(Fmt.stock(27.5), '27,5');
      expect(sortTimes(['20:00', '8:00', '08:00', '14.30']), ['08:00', '14:30', '20:00']);
    });
  });

  group('planul zilei', () {
    test('stările: luat, e ora acum, amânat, ratat, urmează', () {
      final day = DateTime(2026, 11, 21);
      final m = _med(times: const ['08:00', '12:30', '14:00', '20:00']);
      final plan = dayPlan(
        meds: [m],
        reminders: const [ReminderItem(id: 1, kind: ReminderKind.test, title: 'Evaluare completă', time: '10:00')],
        intakes: [Intake(medId: 1, scheduledAt: DateTime(2026, 11, 21, 8), status: IntakeStatus.taken, at: DateTime(2026, 11, 21, 8, 5))],
        testDone: false,
        day: day,
        now: now,
      );
      expect([for (final e in plan) e.time], ['08:00', '10:00', '12:30', '14:00', '20:00']);
      expect(
        [for (final e in plan) e.status],
        [PlanStatus.done, PlanStatus.missed, PlanStatus.missed, PlanStatus.due, PlanStatus.upcoming],
      );
      expect(plan.first.doneAt, DateTime(2026, 11, 21, 8, 5));

      final snoozed = dayPlan(
        meds: [m],
        reminders: const [],
        intakes: [
          Intake(medId: 1, scheduledAt: DateTime(2026, 11, 21, 14), status: IntakeStatus.snoozed, at: DateTime(2026, 11, 21, 14, 20)),
        ],
        testDone: true,
        day: day,
        now: now,
      );
      expect(snoozed.firstWhere((e) => e.time == '14:00').status, PlanStatus.snoozed);
    });

    test('reminderele dezactivate sau din alte zile nu apar', () {
      final plan = dayPlan(
        meds: const [],
        reminders: const [
          ReminderItem(id: 1, kind: ReminderKind.other, title: 'Plimbare', time: '17:00', enabled: false),
          ReminderItem(id: 2, kind: ReminderKind.other, title: 'Exerciții', time: '18:00', days: [1, 3, 5]),
          ReminderItem(id: 3, kind: ReminderKind.other, title: 'Apă', time: '11:00', days: [6]),
        ],
        intakes: const [],
        testDone: false,
        day: DateTime(2026, 11, 21), // sâmbătă
        now: now,
      );
      expect(plan.map((e) => e.reminder!.title), ['Apă']);
      expect(plan.single.status, PlanStatus.passed);
      expect(plan.single.counts, isFalse);
    });

    test('aderența numără doar dozele deja trecute', () {
      final m = _med(times: const ['08:00', '20:00'], created: DateTime(2026, 11, 20));
      final intakes = [
        Intake(medId: 1, scheduledAt: DateTime(2026, 11, 20, 8), status: IntakeStatus.taken),
        Intake(medId: 1, scheduledAt: DateTime(2026, 11, 20, 20), status: IntakeStatus.skipped),
        Intake(medId: 1, scheduledAt: DateTime(2026, 11, 21, 8), status: IntakeStatus.taken),
      ];
      // 20 nov: 08 ✓, 20 ✗; 21 nov: 08 ✓, 20:00 încă n-a venit → 2 din 3.
      expect(adherence(meds: [m], intakes: intakes, from: DateTime(2026, 11, 16), to: DateTime(2026, 11, 23), now: now), 67);
      expect(adherence(meds: const [], intakes: intakes, from: DateTime(2026, 11, 16), to: DateTime(2026, 11, 23), now: now), isNull);
    });

    test('efectul după doză', () {
      SampleRecord s(DateTime at, int i) =>
          SampleRecord(at: at, frequency: 4.8, rms: 1, index: i, state: HandState.rest, fingers: const [null, null, null, null, null]);
      final samples = [
        for (var i = 0; i < 100; i++) s(DateTime(2026, 11, 20, 9, 0, i), 40),
        for (var i = 0; i < 100; i++) s(DateTime(2026, 11, 20, 19, 0, i), 50),
      ];
      final intakes = [
        Intake(medId: 1, scheduledAt: DateTime(2026, 11, 20, 8), status: IntakeStatus.taken, at: DateTime(2026, 11, 20, 8, 10)),
      ];
      expect(afterDoseInsight(samples, intakes), 'În cele 2 ore după o doză, indicele e în medie cu 20 % mai mic.');
      expect(afterDoseInsight(samples, const []), isNull);
    });
  });

  test('notificările programate: o doză pe oră, testul, stocul mic la 10:00', () {
    final notes = plannedNotes(
      meds: [_med(id: 3)],
      reminders: const [
        ReminderItem(id: 2, kind: ReminderKind.test, title: 'Evaluare completă', time: '10:00'),
        ReminderItem(id: 4, kind: ReminderKind.other, title: 'Exerciții', time: '18:00', days: [1, 5]),
        ReminderItem(id: 5, kind: ReminderKind.other, title: 'Oprit', time: '18:00', enabled: false),
      ],
      prefs: const ReminderPrefs(),
      now: now,
    );
    expect(notes.where((n) => n.channel == NoteChannel.medications).map((n) => n.id), [1030, 1031, 1032]);
    expect(notes.firstWhere((n) => n.id == 1031).title, 'E ora pentru Madopar 250 mg');
    expect(notes.firstWhere((n) => n.id == 1031).doseActions, isTrue);
    final stock = notes.firstWhere((n) => n.channel == NoteChannel.stock);
    expect(stock.body, 'Mai ai Madopar pentru 4 zile. Cumpără o cutie.');
    expect(stock.once, DateTime(2026, 11, 22, 10));
    expect(notes.where((n) => n.channel == NoteChannel.tests).single.weekday, isNull);
    expect(notes.where((n) => n.channel == NoteChannel.other).map((n) => n.id), [20041, 20045]);

    final quiet = plannedNotes(meds: [_med(id: 3)], reminders: const [], prefs: const ReminderPrefs(meds: false, stock: false), now: now);
    expect(quiet, isEmpty);
  });

  test('„Am luat” scade din stoc o singură dată; anularea îl pune înapoi; „Am cumpărat” adaugă', () async {
    final db = await AppDatabase.open(inMemoryDatabasePath, factory: databaseFactoryFfi);
    final repo = MedicationRepository(db.raw);
    final m = await repo.save(
      Medication(name: 'Madopar', strength: '250 mg', times: const ['08:00'], stock: 10, createdAt: DateTime(2026, 11, 1)),
    );
    final at = DateTime(2026, 11, 21, 8);
    expect(await repo.markTaken(m.id!, at), isTrue);
    expect(await repo.markTaken(m.id!, at), isFalse);
    expect((await repo.medication(m.id!))!.stock, 9);
    final day = await repo.intakesBetween(DateTime(2026, 11, 21), DateTime(2026, 11, 22));
    expect(day.single.status, IntakeStatus.taken);
    await repo.undo(m.id!, at);
    expect((await repo.medication(m.id!))!.stock, 10);
    expect(await repo.intakesBetween(DateTime(2026, 11, 21), DateTime(2026, 11, 22)), isEmpty);
    await repo.addStock(m.id!, 30);
    expect((await repo.medication(m.id!))!.stock, 40);
    await repo.snooze(m.id!, at, at.add(const Duration(minutes: 10)));
    expect((await repo.intakesBetween(at, at.add(const Duration(hours: 1)))).single.status, IntakeStatus.snoozed);
    await addDemoMedications(db, days: 10);
    expect(await repo.medications(), hasLength(1), reason: 'datele demo nu se adaugă peste medicamentele existente');
    await db.close();
  });

  testWidgets('Remindere: planul de azi, „Am luat” cu anulare, stocul mic, la text 130 %', (tester) async {
    await _loadFont();
    SharedPreferences.setMockInitialValues({'dataSource': 0});
    final prefs = await SharedPreferences.getInstance();
    final t = DateTime.now();
    final nowHm = hm(t.hour, t.minute);
    final db = await tester.runAsync(() async {
      final db = await AppDatabase.open(inMemoryDatabasePath, factory: databaseFactoryFfi);
      final repo = MedicationRepository(db.raw);
      await repo.save(
        Medication(
          name: 'Madopar',
          strength: '250 mg',
          times: [nowHm],
          stock: 3,
          packSize: 100,
          createdAt: t.subtract(const Duration(days: 3)),
        ),
      );
      await repo.save(
        Medication(name: 'Rivotril', strength: '0,5 mg', dose: 0.5, times: const ['22:00'], stock: 28, color: 4, createdAt: t),
      );
      await repo.saveReminder(const ReminderItem(kind: ReminderKind.test, title: 'Evaluare completă', time: '10:00'));
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
        child: const MaterialApp(home: Scaffold(body: RemindersScreen())),
      ),
    );
    await _settle(tester);
    expect(find.textContaining('Mai ai Madopar 250 mg pentru 3 zile'), findsOneWidget);
    expect(find.text('AZI · 0 DIN 3 FĂCUTE'), findsWidgets);
    expect(find.text('Am luat'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('Am luat'));
    await tester.pump();
    await tester.tap(find.text('Am luat'));
    await _settle(tester);
    expect(find.text('Am luat'), findsNothing);
    expect(find.textContaining('luat la'), findsOneWidget);
    final stock = await tester.runAsync(
      () async => (await MedicationRepository(db.raw).medications()).firstWhere((m) => m.name == 'Madopar').stock,
    );
    expect(stock, 2);

    await tester.scrollUntilVisible(find.text('Rivotril 0,5 mg'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Evaluare completă'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.runAsync(db.close);
  });

  testWidgets('formularele de medicament și de reminder se desenează la text 130 %', (tester) async {
    await _loadFont();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearAllTestValues();
    });
    for (final screen in <Widget>[
      MedicationEditScreen(medication: _med()),
      const MedicationEditScreen(),
      const ReminderEditScreen(kind: ReminderKind.test),
      const ReminderEditScreen(),
    ]) {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [prefsProvider.overrideWithValue(prefs)],
          child: MaterialApp(home: screen),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull, reason: screen.toString());
    }
    // Formularul gol: „Salvează” e oprit până scrii numele.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [prefsProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: MedicationEditScreen()),
      ),
    );
    await tester.pump();
    await tester.scrollUntilVisible(find.text('Scrie numele medicamentului.'), 400, scrollable: find.byType(Scrollable).first);
    expect(find.text('Scrie numele medicamentului.'), findsOneWidget);
    await tester.scrollUntilVisible(find.byType(TextField).first, -400, scrollable: find.byType(Scrollable).first);
    await tester.enterText(find.byType(TextField).first, 'Propranolol');
    await tester.pump();
    expect(find.text('Scrie numele medicamentului.'), findsNothing);
  });
}
