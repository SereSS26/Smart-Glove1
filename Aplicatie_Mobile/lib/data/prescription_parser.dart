import 'medications.dart';

/// Un medicament citit dintr-o rețetă sau dintr-un mesaj. [uncertain] spune ce trebuie verificat cu ochii.
class ParsedMed {
  ParsedMed({
    required this.name,
    this.strength = '',
    this.form = MedForm.tablet,
    this.dose = 1,
    this.times = const ['08:00'],
    this.quantity,
    this.days,
    Set<String>? uncertain,
    this.source = '',
  }) : uncertain = uncertain ?? {};

  String name;
  String strength;
  MedForm form;
  double dose;
  List<String> times;

  /// Câte bucăți scrie că sunt (ex. „30 cp”), dacă scrie.
  int? quantity;

  /// Durata tratamentului în zile, dacă scrie.
  int? days;

  /// 'name', 'dose', 'times', 'stock'.
  final Set<String> uncertain;

  /// Rândul (sau rândurile) din care a fost citit.
  String source;

  Medication toMedication({int color = 0, DateTime? now}) {
    final qty = quantity;
    return Medication(
      name: name,
      strength: strength,
      form: form,
      dose: dose,
      times: times,
      stock: (qty ?? 30).toDouble(),
      packSize: qty ?? 30,
      color: color,
      note: days == null ? '' : 'timp de $days zile',
      createdAt: now ?? DateTime.now(),
    );
  }

  @override
  String toString() => '$name $strength · $dose ${form.short} · ${times.join(',')} · qty=$quantity days=$days ?$uncertain';
}

String _fold(String s) {
  const from = 'ăâîșşțţĂÂÎȘŞȚŢ';
  const to = 'aaissttAAISSTT';
  final b = StringBuffer();
  for (final r in s.runes) {
    final c = String.fromCharCode(r);
    final i = from.indexOf(c);
    b.write(i >= 0 ? to[i] : c);
  }
  return b.toString().toLowerCase();
}

final _num = r'(\d+(?:[.,]\d+)?)';
final _strengthRe = RegExp('$_num(?:\\s*/\\s*$_num)?\\s*(mg|mcg|µg|ug|g|ml|ui|iu|u\\.i\\.)(?![a-z])', caseSensitive: false);
final _unitWord = r'(cp|cpr|compr\w*|comprimat\w*|tb|tbl|tab\w*|caps\w*|cps|pic\w*|plic\w*|fiol\w*|dr|drajeu\w*|doz\w*)';
final _amount = r'(\d+(?:[.,]\d+)?|\d\s*/\s*\d|½|¼|¾|1½|jumatate|o|un|una|doua|doi|trei)';
final _doseRe = RegExp('(?<![\\w/.,])$_amount\\s*(?:x\\s*)?$_unitWord(?![a-z])');
const _slot = r'(\d(?:[.,/]\d)?|½|¼)';
final _schemeRe = RegExp('(?<![\\d/.,])$_slot\\s*-\\s*$_slot\\s*-\\s*$_slot(?:\\s*-\\s*$_slot)?(?![\\d])');
final _timesPerDayRe = RegExp(
  r'(?:de\s+)?(\d|o|una|doua|trei|patru)\s*(?:ori|x)\s*(?:pe|/|\s)?\s*(?:zi|zilnic)|(?:x|de)\s*(\d)\s*(?:/|pe)\s*zi|(\d)\s*/\s*zi(?!le)',
);
final _everyHoursRe = RegExp(r'(?:la|din)\s+(?:fiecare\s+)?(\d{1,2})\s*(?:ore|h)\b');
final _clockRe = RegExp(r'(?<![\d.,])([01]?\d|2[0-3])[:.]([0-5]\d)(?![\d])');
final _atHourRe = RegExp(
  r'\b(?:ora|orele|la ora|la orele|la)\s+((?:[01]?\d|2[0-3])(?:\s*(?:,|si|și|și|-)\s*(?:[01]?\d|2[0-3]))*)(?![\d:.,]|\s*(?:mg|ore|zile|cp))',
);
final _daysRe = RegExp(r'(?:timp\s+de|pentru|x)?\s*(\d{1,3})\s*(zile|zi\b|saptamani|luni|luna)');
final _qtyRe = RegExp(
  r'(?:cutie\s+(?:de|cu)\s+|nr\.?\s*|#\s*|cant(?:itate)?\.?\s*:?\s*|n\s*=\s*|\()\s*(\d{1,3})\s*\)?(?:\s*' + _unitWord + r')?',
);

const _stopWords = [
  'cnp',
  'diagnostic',
  'medic',
  'spital',
  'clinic',
  'data',
  'semnatura',
  'parafa',
  'cod ',
  'pacient',
  'varsta',
  'adresa',
  'telefon',
  'judet',
  'cas ',
  'fisa',
  'serie',
  'reteta',
  'unitatea',
  'specialitate',
  'asigurat',
  'tel.',
  'email',
];

double? _amountValue(String raw) {
  final s = raw.replaceAll(' ', '');
  switch (s) {
    case '½' || 'jumatate':
      return 0.5;
    case '¼':
      return 0.25;
    case '¾':
      return 0.75;
    case '1½':
      return 1.5;
    case 'o' || 'un' || 'una':
      return 1;
    case 'doua' || 'doi':
      return 2;
    case 'trei':
      return 3;
  }
  final frac = RegExp(r'^(\d)/(\d)$').firstMatch(s);
  if (frac != null) return int.parse(frac.group(1)!) / int.parse(frac.group(2)!);
  return double.tryParse(s.replaceAll(',', '.'));
}

int? _wordNum(String? s) => switch (s) {
  null => null,
  'o' || 'una' => 1,
  'doua' => 2,
  'trei' => 3,
  'patru' => 4,
  _ => int.tryParse(s),
};

MedForm _formOf(String unit) {
  if (unit.startsWith('cap') || unit == 'cps') return MedForm.capsule;
  if (unit.startsWith('pic')) return MedForm.drops;
  if (unit.startsWith('plic')) return MedForm.sachet;
  if (unit == 'ml') return MedForm.ml;
  return MedForm.tablet;
}

List<String> _timesFor(int n) => switch (n) {
  <= 1 => ['08:00'],
  2 => ['08:00', '20:00'],
  3 => ['08:00', '14:00', '20:00'],
  4 => ['08:00', '12:00', '16:00', '20:00'],
  _ => ['06:00', '10:00', '14:00', '18:00', '22:00'],
};

List<String> _everyHours(int h) {
  if (h <= 0 || h > 24) return ['08:00'];
  final start = h == 8 ? 6 : 8;
  return sortTimes([for (var t = start; t < start + 24; t += h) hm(t % 24, 0)]);
}

/// Ce scrie despre ore și doză pe un rând (sau pe rândurile lipite de el).
class _Dosing {
  double? dose;
  MedForm? form;
  List<String>? times;
  bool timesGuessed = false;
  bool doseMixed = false;
  int? quantity;
  int? days;

  bool get any => dose != null || times != null || quantity != null || days != null;
}

_Dosing _dosing(String folded) {
  final d = _Dosing();
  var rest = folded;

  // Schema 1-0-1 (dimineața-prânz-seara[-culcare]).
  final scheme = _schemeRe.firstMatch(rest);
  if (scheme != null) {
    final parts = [for (var i = 1; i <= 4; i++) scheme.group(i)].whereType<String>().map(_amountValue).toList();
    if (parts.every((p) => p != null)) {
      const slots = ['08:00', '14:00', '20:00', '22:00'];
      final times = [
        for (var i = 0; i < parts.length; i++)
          if (parts[i]! > 0) slots[i],
      ];
      final nonZero = parts.whereType<double>().where((p) => p > 0).toSet();
      if (times.isNotEmpty) {
        d.times = times;
        if (nonZero.length == 1) d.dose = nonZero.first;
        if (nonZero.length > 1) {
          d.dose = nonZero.reduce((a, b) => a > b ? a : b);
          d.doseMixed = true;
        }
      }
      rest = rest.replaceRange(scheme.start, scheme.end, ' ');
    }
  }

  final qty = _qtyRe.firstMatch(rest);
  if (qty != null) {
    d.quantity = int.tryParse(qty.group(1)!);
    rest = rest.replaceRange(qty.start, qty.end, ' ');
  }

  final days = _daysRe.firstMatch(rest);
  if (days != null) {
    final n = int.parse(days.group(1)!);
    d.days = switch (days.group(2)) {
      'saptamani' => n * 7,
      'luni' || 'luna' => n * 30,
      _ => n,
    };
    rest = rest.replaceRange(days.start, days.end, ' ');
  }

  // Doza și cantitatea: „1 cp” e doză, „30 cp” e cutia.
  for (final m in _doseRe.allMatches(rest)) {
    final v = _amountValue(m.group(1)!);
    if (v == null) continue;
    final unit = m.group(2)!;
    if (v >= 10 && v == v.roundToDouble()) {
      d.quantity ??= v.round();
    } else if (d.dose == null || (d.dose == 1 && scheme == null)) {
      d.dose = v;
    }
    d.form ??= _formOf(unit);
  }
  if (d.form == null && RegExp(r'\bml\b').hasMatch(rest) && d.dose == null) d.form = MedForm.ml;

  if (d.times == null) {
    final clocks = [for (final m in _clockRe.allMatches(rest)) hm(int.parse(m.group(1)!), int.parse(m.group(2)!))];
    final atHours = <String>[];
    for (final m in _atHourRe.allMatches(rest)) {
      for (final h in RegExp(r'\d{1,2}').allMatches(m.group(1)!)) {
        atHours.add(hm(int.parse(h.group(0)!), 0));
      }
    }
    final words = <String>[
      if (RegExp(r'dimineat|dimin\.|matinal').hasMatch(rest)) '08:00',
      if (RegExp(r'pranz|amiaz').hasMatch(rest)) '14:00',
      if (RegExp(r'\bseara|vesper').hasMatch(rest)) '20:00',
      if (RegExp(r'culcare|noaptea|inainte de somn').hasMatch(rest)) '22:00',
    ];
    final every = _everyHoursRe.firstMatch(rest);
    final perDay = _timesPerDayRe.firstMatch(rest);
    if (clocks.isNotEmpty || atHours.isNotEmpty) {
      d.times = sortTimes([...clocks, ...atHours]);
    } else if (words.isNotEmpty) {
      d.times = words;
    } else if (every != null) {
      d.times = _everyHours(int.parse(every.group(1)!));
      d.timesGuessed = true;
    } else if (perDay != null) {
      final n = _wordNum(perDay.group(1)) ?? _wordNum(perDay.group(2)) ?? _wordNum(perDay.group(3)) ?? 1;
      d.times = _timesFor(n);
      d.timesGuessed = n > 3;
    } else if (RegExp(r'/\s*zi\b|\bzilnic|pe zi\b').hasMatch(rest)) {
      d.times = ['08:00'];
    }
  }
  return d;
}

String _cleanName(String raw) {
  var s = raw
      .replaceAll(RegExp(r'^\s*(?:rp\.?\s*/?|\d{1,2}\s*[.)]|[-•*–—·]+)\s*', caseSensitive: false), '')
      .replaceAll(
        RegExp(
          r'\b(?:comprimate|comprimat|tablete|capsule|cpr|cps|caps|cp|tb|film(?:ate)?|filmate|cu eliberare prelungita|retard)\b\.?',
          caseSensitive: false,
        ),
        ' ',
      )
      .replaceAll(RegExp(r'[,;:()\[\]"„”]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  s = s.replaceAll(RegExp(r'[-–—./]+$'), '').trim();
  if (s.isEmpty) return s;
  if (s == s.toUpperCase() && s.length > 2) {
    s = s.split(' ').map((w) => w.isEmpty ? w : '${w[0]}${w.substring(1).toLowerCase()}').join(' ');
  }
  return '${s[0].toUpperCase()}${s.substring(1)}';
}

bool _looksLikeName(String s) => RegExp(r'[A-Za-zĂÂÎȘŞȚŢăâîșşțţ]{3,}').hasMatch(s);

/// Citește medicamentele dintr-un text de rețetă (tipărit, scanat cu ML Kit sau copiat din Notițe).
/// Reguli scrise pentru română; tot ce nu e sigur e marcat pentru verificare.
List<ParsedMed> parsePrescription(String text) {
  final lines = text
      .replaceAll('\r', '\n')
      .split(RegExp(r'\n|;(?=\s*[A-ZĂÂÎȘȚ])|(?<=\S)\s+(?=\d{1,2}[.)]\s+[A-ZĂÂÎȘȚ])'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  final out = <ParsedMed>[];
  for (final line in lines) {
    final folded = _fold(line);
    final strength = _strengthRe.firstMatch(line);
    // Concentrația iese din calcul, ca „1,25 mg” să nu pară o oră sau o doză.
    final dosing = _dosing(folded.replaceAll(_strengthRe, ' '));
    final isStop = strength == null && _stopWords.any(folded.contains);
    if (isStop) continue;

    // Numele: ce e înaintea concentrației, sau primele cuvinte până la prima cifră / doză.
    String namePart;
    if (strength != null) {
      namePart = line.substring(0, strength.start);
    } else {
      // Fără numărul din listă („1.”), altfel numele s-ar tăia chiar la el.
      final body = line.replaceFirst(RegExp(r'^\s*(?:rp\.?\s*/?\s*)?(?:\d{1,2}\s*[.)]|[-•*–—·]+)?\s*', caseSensitive: false), '');
      final cut = RegExp(r'\d|\b(?:cate|câte|d\.?s\.?|s:|cp\b|caps)', caseSensitive: false).firstMatch(body);
      namePart = cut == null ? body : body.substring(0, cut.start);
    }
    final name = _cleanName(namePart);
    final hasName =
        _looksLikeName(name) &&
        !RegExp(r'^(?:d\.?s|s|ds|mod de administrare|administrare|cate|câte|doza)\b', caseSensitive: false).hasMatch(name);

    if (!hasName) {
      // Rând doar cu instrucțiuni: se lipește de medicamentul de deasupra.
      if (out.isNotEmpty && dosing.any) _merge(out.last, dosing, line);
      continue;
    }
    if (strength == null && !dosing.any) continue; // un rând oarecare, fără concentrație și fără doză

    final st = strength == null
        ? ''
        : '${strength.group(1)!.replaceAll('.', ',')}${strength.group(2) == null ? '' : '/${strength.group(2)!.replaceAll('.', ',')}'} ${_unitLabel(strength.group(3)!)}';
    final med = ParsedMed(name: name, strength: st, source: line);
    if (strength == null || name.split(' ').length > 3 || RegExp(r'[0-9@#%&]').hasMatch(name)) med.uncertain.add('name');
    _apply(med, dosing);
    out.add(med);
  }
  for (final m in out) {
    if (m.uncertain.contains('_noTimes')) {
      m.uncertain
        ..remove('_noTimes')
        ..add('times');
    }
    if (m.quantity == null) m.uncertain.add('stock');
  }
  return out;
}

String _unitLabel(String u) => switch (u.toLowerCase()) {
  'ui' || 'iu' || 'u.i.' => 'UI',
  'µg' || 'ug' => 'mcg',
  final x => x,
};

void _apply(ParsedMed m, _Dosing d) {
  if (d.dose != null) {
    m.dose = d.dose!;
  } else {
    m.uncertain.add('dose');
  }
  if (d.doseMixed) m.uncertain.add('dose');
  if (d.form != null) m.form = d.form!;
  if (d.times != null) {
    m.times = d.times!;
    if (d.timesGuessed) m.uncertain.add('times');
  } else {
    m.uncertain.add('_noTimes');
  }
  m.quantity = d.quantity ?? m.quantity;
  m.days = d.days ?? m.days;
}

void _merge(ParsedMed m, _Dosing d, String line) {
  m.source = '${m.source}\n$line';
  if (d.dose != null && m.uncertain.contains('dose')) {
    m.dose = d.dose!;
    m.uncertain.remove('dose');
    if (d.doseMixed) m.uncertain.add('dose');
  }
  if (d.form != null) m.form = d.form!;
  if (d.times != null && m.uncertain.contains('_noTimes')) {
    m.times = d.times!;
    m.uncertain.remove('_noTimes');
    if (d.timesGuessed) m.uncertain.add('times');
  }
  m.quantity ??= d.quantity;
  m.days ??= d.days;
}
