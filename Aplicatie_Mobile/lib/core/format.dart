/// Formatări în română: virgulă zecimală, date și durate.
abstract final class Fmt {
  static String hz(double hz) => hz <= 0 ? '—' : hz.toStringAsFixed(1).replaceAll('.', ',');

  /// Cantități de medicament: 1, ½, 1½, ¼, 2,5 → „1”, „½”, „1½”, „¼”, „2,5”.
  static String qty(double v) {
    final whole = v.floor();
    final frac = ((v - whole) * 100).round();
    final w = whole == 0 ? '' : '$whole';
    return switch (frac) {
      0 => '$whole',
      50 => '$w½',
      25 => '$w¼',
      75 => '$w¾',
      _ => v.toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll('.', ','),
    };
  }

  /// Stocul: „12”, „27,5”.
  static String stock(double v) => v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1).replaceAll('.', ',');

  static String duration(Duration d) {
    final m = d.inMinutes;
    if (m < 1) return '${d.inSeconds} s';
    if (m < 60) return '$m min';
    return '${d.inHours} h ${m % 60} min';
  }

  /// 04:12
  static String clock(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }

  static String time(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';

  static String _two(int v) => v.toString().padLeft(2, '0');

  /// „12 nov”
  static String shortDate(DateTime t) => '${t.day} ${shortMonths[t.month - 1]}';

  /// „Azi, 09:14”, „Ieri, 20:30” sau „12 nov, 08:40”.
  static String dayAndTime(DateTime t, {DateTime? now}) {
    final today = _day(now ?? DateTime.now());
    final day = _day(t);
    final hm = time(t);
    if (day == today) return 'Azi, $hm';
    if (day == today.subtract(const Duration(days: 1))) return 'Ieri, $hm';
    return '${shortDate(t)}, $hm';
  }

  /// „joi, 12 nov · 09:14”
  static String longDate(DateTime t) => '${weekdays[t.weekday - 1]}, ${shortDate(t)} · ${time(t)}';

  /// „sâmbătă, 21 noiembrie”
  static String weekdayDate(DateTime t) => '${weekdays[t.weekday - 1]}, ${t.day} ${months[t.month - 1]}';

  static const weekdays = ['luni', 'marți', 'miercuri', 'joi', 'vineri', 'sâmbătă', 'duminică'];
  static const months = [
    'ianuarie',
    'februarie',
    'martie',
    'aprilie',
    'mai',
    'iunie',
    'iulie',
    'august',
    'septembrie',
    'octombrie',
    'noiembrie',
    'decembrie',
  ];

  static const shortMonths = ['ian', 'feb', 'mar', 'apr', 'mai', 'iun', 'iul', 'aug', 'sept', 'oct', 'nov', 'dec'];

  static String fileStamp(DateTime t) => '${t.year}-${_two(t.month)}-${_two(t.day)}_${_two(t.hour)}-${_two(t.minute)}';

  static DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);
}
