import 'package:flutter_test/flutter_test.dart';
import 'package:manusa_app/data/medications.dart';
import 'package:manusa_app/data/prescription_parser.dart';

ParsedMed one(String line) {
  final r = parsePrescription(line);
  expect(r, hasLength(1), reason: '„$line” → $r');
  return r.single;
}

void main() {
  group('un rând', () {
    final cases = <String, (String name, String strength, double dose, List<String> times)>{
      'Madopar 250 mg, 1 cp de 3 ori pe zi': ('Madopar', '250 mg', 1, ['08:00', '14:00', '20:00']),
      'Rp./ Propranolol 40mg - 1-0-1': ('Propranolol', '40 mg', 1, ['08:00', '20:00']),
      'Sinemet 25/250 mg 1/2 cp dimineața și seara': ('Sinemet', '25/250 mg', 0.5, ['08:00', '20:00']),
      'Rivotril 0,5 mg ½ cp la culcare': ('Rivotril', '0,5 mg', 0.5, ['22:00']),
      'Levodopa/Carbidopa 100/25 mg 1 tb x 3/zi': ('Levodopa/Carbidopa', '100/25 mg', 1, ['08:00', '14:00', '20:00']),
      'Requip 2 mg 1 cp/zi': ('Requip', '2 mg', 1, ['08:00']),
      'Azilect 1mg 1cp dimineata': ('Azilect', '1 mg', 1, ['08:00']),
      'MADOPAR 125 MG CPS. 1-1-1': ('Madopar', '125 mg', 1, ['08:00', '14:00', '20:00']),
      'Pramipexol 0,18 mg — 1 cp la ora 8, 14 și 20': ('Pramipexol', '0,18 mg', 1, ['08:00', '14:00', '20:00']),
      'Primidonă 250 mg 2 cp seara': ('Primidonă', '250 mg', 2, ['20:00']),
      'Topiramat 25 mg 1 cp la 08:00 și 1 cp la 20:30': ('Topiramat', '25 mg', 1, ['08:00', '20:30']),
      'Gabapentin 300 mg câte o capsulă de două ori pe zi': ('Gabapentin', '300 mg', 1, ['08:00', '20:00']),
      'Clonazepam 0.5mg 0-0-1': ('Clonazepam', '0,5 mg', 1, ['20:00']),
      'Sinemet CR 50/200 mg 1-½-1': ('Sinemet CR', '50/200 mg', 1, ['08:00', '14:00', '20:00']),
      '1. Amantadină 100 mg 1 cp dimineața și la prânz': ('Amantadină', '100 mg', 1, ['08:00', '14:00']),
      'Vitamina D3 1000 UI 1 cp/zi': ('Vitamina D3', '1000 UI', 1, ['08:00']),
      'Propranolol 10 mg, 1 cp la 12 ore': ('Propranolol', '10 mg', 1, ['08:00', '20:00']),
      'Madopar 62,5 mg 1 cp de 4 ori pe zi': ('Madopar', '62,5 mg', 1, ['08:00', '12:00', '16:00', '20:00']),
      '- Rasagilina 1 mg dimineața, 30 cp': ('Rasagilina', '1 mg', 1, ['08:00']),
      'Xadago 50 mg 1 compr. pe zi, timp de 30 zile': ('Xadago', '50 mg', 1, ['08:00']),
      'Neupro 4 mg/24h plasture 1/zi': ('Neupro', '4 mg', 1, ['08:00']),
    };
    for (final c in cases.entries) {
      test(c.key, () {
        final m = one(c.key);
        expect(m.name, c.value.$1);
        expect(m.strength, c.value.$2);
        expect(m.dose, c.value.$3);
        expect(m.times, c.value.$4);
      });
    }
  });

  test('cantitatea, durata și forma', () {
    final a = one('- Rasagilina 1 mg dimineața, 30 cp');
    expect(a.quantity, 30);
    expect(a.uncertain, isNot(contains('stock')));
    final b = one('Xadago 50 mg 1 compr. pe zi, timp de 30 zile');
    expect(b.days, 30);
    expect(b.quantity, isNull);
    expect(b.uncertain, contains('stock'));
    expect(one('Gabapentin 300 mg câte o capsulă de două ori pe zi').form, MedForm.capsule);
    expect(one('Akineton 2 mg 1 cp de 2 ori pe zi, cutie de 50').quantity, 50);
    expect(one('Levetiracetam 100 mg/ml soluție 5 ml de 2 ori pe zi').form, MedForm.ml);
  });

  test('o rețetă întreagă: antetul se ignoră, instrucțiunile de pe rândul următor se lipesc', () {
    const text = '''
SPITALUL CLINIC JUDEȚEAN
Medic: Dr. Andreea Pavel, neurolog
Pacient: Ion Popescu   CNP 1580101123456
Diagnostic: Boala Parkinson
Data: 12.11.2026
Rp./
1. Madopar 250 mg
   D.S. 1 cp de 3 ori pe zi
2. Rivotril 0,5 mg  ½ cp seara la culcare  (30)
3. Propranolol 40 mg 1-0-1 #60
Semnătura și parafa
''';
    final r = parsePrescription(text);
    expect(r.map((m) => m.name), ['Madopar', 'Rivotril', 'Propranolol']);
    expect(r[0].times, ['08:00', '14:00', '20:00']);
    expect(r[0].uncertain, isNot(contains('times')));
    expect(r[1].dose, 0.5);
    expect(r[1].times, ['20:00', '22:00']);
    expect(r[1].quantity, 30);
    expect(r[2].quantity, 60);
    expect(r[2].times, ['08:00', '20:00']);
  });

  test('un mesaj din Notițe, pe un singur rând', () {
    final r = parsePrescription('Madopar 250 mg 1-1-1; Rivotril 0,5 mg seara');
    expect(r.map((m) => m.name), ['Madopar', 'Rivotril']);
    expect(r[1].times, ['20:00']);
    expect(r[1].uncertain, contains('dose'));
  });

  test('ce nu e sigur se marchează', () {
    final numbered = one('2. Madopar 1-1-1 (100)');
    expect(numbered.name, 'Madopar');
    expect(numbered.uncertain, contains('name'), reason: 'fără concentrație');
    final m = one('Paracetamol 1 cp la nevoie');
    expect(m.uncertain, containsAll(['name', 'times', 'stock']));
    expect(one('MADOPAR 125 MG CPS. 1-1-1').uncertain, isNot(contains('dose')), reason: '1-1-1 înseamnă clar câte 1');
    final mixed = one('Sinemet CR 50/200 mg 1-½-1');
    expect(mixed.uncertain, contains('dose'));
    expect(parsePrescription('Data: 12-05-2026\nTel. 0722 000 000\nCu stimă'), isEmpty);
  });

  test('devine medicament cu stocul din rețetă', () {
    final med = one('- Rasagilina 1 mg dimineața, 30 cp').toMedication(now: DateTime(2026, 11, 21));
    expect(med.title, 'Rasagilina 1 mg');
    expect(med.stock, 30);
    expect(med.packSize, 30);
    expect(med.daysLeft, 30);
  });
}
