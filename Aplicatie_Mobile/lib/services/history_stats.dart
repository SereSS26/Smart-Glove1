import '../core/format.dart';
import '../data/db/models.dart';

/// Perioada din Istoric.
enum Period { day, week, month }

/// Intervalul unei perioade: [start, end), plus eticheta afișată.
class PeriodRange {
  const PeriodRange(this.start, this.end, this.label);
  final DateTime start;
  final DateTime end;
  final String label;

  bool contains(DateTime t) => !t.isBefore(start) && t.isBefore(end);
  int get days => end.difference(start).inHours ~/ 24;
}

DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);

/// Intervalul perioadei [p], mutat cu [offset] perioade înapoi (0 = cea de acum).
/// Săptămâna începe lunea; luna e luna calendaristică.
PeriodRange rangeFor(Period p, int offset, DateTime now) {
  final today = _day(now);
  switch (p) {
    case Period.day:
      final d = DateTime(today.year, today.month, today.day - offset);
      final label = offset == 0
          ? 'Azi · ${d.day} ${Fmt.months[d.month - 1]}'
          : (offset == 1 ? 'Ieri · ${d.day} ${Fmt.months[d.month - 1]}' : Fmt.weekdayDate(d));
      return PeriodRange(d, DateTime(d.year, d.month, d.day + 1), label);
    case Period.week:
      final monday = DateTime(today.year, today.month, today.day - (today.weekday - 1) - 7 * offset);
      final sunday = DateTime(monday.year, monday.month, monday.day + 6);
      final label = monday.month == sunday.month
          ? '${monday.day} – ${sunday.day} ${Fmt.months[sunday.month - 1]}'
          : '${monday.day} ${Fmt.months[monday.month - 1]} – ${sunday.day} ${Fmt.months[sunday.month - 1]}';
      return PeriodRange(monday, DateTime(monday.year, monday.month, monday.day + 7), label);
    case Period.month:
      final m = DateTime(today.year, today.month - offset);
      final name = Fmt.months[m.month - 1];
      return PeriodRange(m, DateTime(m.year, m.month + 1), '${name[0].toUpperCase()}${name.substring(1)} ${m.year}');
  }
}

/// O bară din grafic: eticheta, media (null = fără date) și dacă e „acum”.
class StatBar {
  const StatBar(this.label, this.value, {this.highlight = false, this.dose = false});
  final String label;
  final double? value;
  final bool highlight;

  /// O doză luată în acel interval (marcaj sub bară).
  final bool dose;
}

/// O zi din calendarul lunii: ziua, media ei (null = fără date), dacă e azi și dacă e în viitor.
class DayCell {
  const DayCell(this.day, this.value, {this.today = false, this.future = false});
  final int day;
  final double? value;
  final bool today;
  final bool future;
}

/// Tot ce arată Istoricul pentru o perioadă.
class PeriodStats {
  const PeriodStats({
    required this.range,
    required this.mean,
    required this.deltaPercent,
    required this.overThreshold,
    required this.peak,
    required this.sessions,
    required this.testDays,
    required this.bars,
    required this.cells,
    required this.leadingBlanks,
  });

  final PeriodRange range;

  /// Media indicelui pe toate secundele înregistrate; null = fără date.
  final double? mean;

  /// Diferența față de perioada anterioară, în procente (minus = mai puțin tremor = mai bine).
  final int? deltaPercent;

  /// Cât din timpul înregistrat a fost peste prag, în procente.
  final double? overThreshold;
  final int? peak;
  final int sessions;

  /// În câte zile s-a făcut cel puțin un test.
  final int testDays;
  final List<StatBar> bars;

  /// Calendarul lunii (doar la [Period.month]) și câte căsuțe goale îl preced (luni = prima coloană).
  final List<DayCell> cells;
  final int leadingBlanks;
}

double? _mean(Iterable<num> xs) {
  var s = 0.0, n = 0;
  for (final x in xs) {
    s += x;
    n++;
  }
  return n == 0 ? null : s / n;
}

/// Calculează statisticile unei perioade din eșantioanele ei (unul pe secundă) și ale celei anterioare.
PeriodStats computeStats({
  required Period period,
  required PeriodRange range,
  required List<SampleRecord> samples,
  required List<SampleRecord> previous,
  required List<SessionRecord> sessions,
  required int threshold,
  required DateTime now,
  Set<int> doseHours = const {},
}) {
  final inRange = samples.where((s) => range.contains(s.at)).toList();
  final mean = _mean(inRange.map((s) => s.index));
  final prevMean = _mean(previous.map((s) => s.index));
  final delta = mean == null || prevMean == null || prevMean == 0 ? null : ((mean - prevMean) / prevMean * 100).round();
  final over = inRange.isEmpty ? null : 100 * inRange.where((s) => s.index > threshold).length / inRange.length;
  final peak = inRange.isEmpty ? null : inRange.map((s) => s.index).reduce((a, b) => a > b ? a : b);
  final periodSessions = sessions.where((s) => range.contains(s.startedAt)).toList();
  final testDays = periodSessions.where((s) => s.kind != SessionKind.free).map((s) => _day(s.startedAt)).toSet().length;

  final bars = <StatBar>[];
  final cells = <DayCell>[];
  var blanks = 0;
  final today = _day(now);
  switch (period) {
    case Period.day:
      for (var h = 6; h <= 23; h++) {
        bars.add(
          StatBar(
            h % 3 == 0 ? '$h' : '',
            _mean(inRange.where((s) => s.at.hour == h).map((s) => s.index)),
            highlight: range.contains(now) && now.hour == h,
            dose: doseHours.contains(h),
          ),
        );
      }
    case Period.week:
      const letters = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
      for (var d = 0; d < 7; d++) {
        final day = DateTime(range.start.year, range.start.month, range.start.day + d);
        bars.add(StatBar(letters[d], _mean(inRange.where((s) => _day(s.at) == day).map((s) => s.index)), highlight: day == today));
      }
    case Period.month:
      blanks = range.start.weekday - 1;
      final byDay = <int, List<int>>{};
      for (final s in inRange) {
        byDay.putIfAbsent(s.at.day, () => []).add(s.index);
      }
      for (var d = 1; d <= range.days; d++) {
        final date = DateTime(range.start.year, range.start.month, d);
        cells.add(DayCell(d, _mean(byDay[d] ?? const []), today: date == today, future: date.isAfter(today)));
        bars.add(StatBar(d % 5 == 0 ? '$d' : '', _mean(byDay[d] ?? const []), highlight: date == today));
      }
  }

  return PeriodStats(
    range: range,
    mean: mean,
    deltaPercent: delta,
    overThreshold: over,
    peak: peak,
    sessions: periodSessions.length,
    testDays: testDays,
    bars: bars,
    cells: cells,
    leadingBlanks: blanks,
  );
}

/// Observații simple din datele tale (nu sfaturi medicale): dimineața față de seară.
String? morningEveningInsight(List<SampleRecord> samples) {
  final morning = _mean(samples.where((s) => s.at.hour >= 6 && s.at.hour < 12).map((s) => s.index));
  final evening = _mean(samples.where((s) => s.at.hour >= 18 && s.at.hour <= 23).map((s) => s.index));
  if (morning == null || evening == null || morning == 0) return null;
  final d = ((evening - morning) / morning * 100).round();
  if (d.abs() < 8) return 'Tremorul e cam la fel dimineața și seara.';
  return d > 0 ? 'Seara, tremorul e cu $d % mai mare decât dimineața.' : 'Seara, tremorul e cu ${-d} % mai mic decât dimineața.';
}

/// Statisticile ultimelor [days] zile (7, 30 sau 90), pentru medic: bare pe zile (pe săptămâni la 90)
/// și calendarul ultimelor zile (cel mult 5 săptămâni).
PeriodStats rollingStats({
  required int days,
  required List<SampleRecord> samples,
  required List<SampleRecord> previous,
  required List<SessionRecord> sessions,
  required int threshold,
  required DateTime now,
}) {
  final today = _day(now);
  final start = DateTime(today.year, today.month, today.day - days + 1);
  final range = PeriodRange(start, DateTime(today.year, today.month, today.day + 1), 'ultimele $days zile');
  final base = computeStats(
    period: Period.day,
    range: range,
    samples: samples,
    previous: previous,
    sessions: sessions,
    threshold: threshold,
    now: now,
  );
  final byDay = <DateTime, List<int>>{};
  for (final s in samples) {
    if (range.contains(s.at)) byDay.putIfAbsent(_day(s.at), () => []).add(s.index);
  }
  final bars = <StatBar>[];
  if (days <= 31) {
    const letters = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    for (var d = 0; d < days; d++) {
      final day = DateTime(start.year, start.month, start.day + d);
      final label = days <= 7 ? letters[day.weekday - 1] : (day.day % 5 == 0 ? '${day.day}' : '');
      bars.add(StatBar(label, _mean(byDay[day] ?? const []), highlight: day == today));
    }
  } else {
    for (var w = 0; w * 7 < days; w++) {
      final values = <int>[];
      for (var d = w * 7; d < w * 7 + 7 && d < days; d++) {
        values.addAll(byDay[DateTime(start.year, start.month, start.day + d)] ?? const []);
      }
      bars.add(StatBar(w % 2 == 0 ? 'S${w + 1}' : '', _mean(values), highlight: (w + 1) * 7 >= days));
    }
  }
  final calDays = days < 35 ? days : 35;
  final calStart = DateTime(today.year, today.month, today.day - calDays + 1);
  final cells = [
    for (var d = 0; d < calDays; d++)
      () {
        final day = DateTime(calStart.year, calStart.month, calStart.day + d);
        return DayCell(day.day, _mean(byDay[day] ?? const []), today: day == today);
      }(),
  ];
  return PeriodStats(
    range: range,
    mean: base.mean,
    deltaPercent: base.deltaPercent,
    overThreshold: base.overThreshold,
    peak: base.peak,
    sessions: base.sessions,
    testDays: base.testDays,
    bars: bars,
    cells: cells,
    leadingBlanks: calStart.weekday - 1,
  );
}

/// Media pe fiecare zi din ultimele [days] zile (null = fără date), pentru mini-graficele medicului.
List<double?> dailyMeans(List<SampleRecord> samples, {required int days, required DateTime now}) {
  final today = _day(now);
  final byDay = <DateTime, List<int>>{};
  for (final s in samples) {
    byDay.putIfAbsent(_day(s.at), () => []).add(s.index);
  }
  return [for (var d = days - 1; d >= 0; d--) _mean(byDay[DateTime(today.year, today.month, today.day - d)] ?? const [])];
}
