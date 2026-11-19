import 'package:intl/intl.dart';

/// Formatări în română: virgulă zecimală, date și durate.
abstract final class Fmt {
  static String hz(double hz) => hz <= 0 ? '—' : hz.toStringAsFixed(1).replaceAll('.', ',');

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

  static String time(DateTime t) => DateFormat.Hm('ro').format(t);

  /// „Azi, 09:14”, „Ieri, 20:30” sau „12 nov, 08:40”.
  static String dayAndTime(DateTime t, {DateTime? now}) {
    final today = _day(now ?? DateTime.now());
    final day = _day(t);
    final hm = time(t);
    if (day == today) return 'Azi, $hm';
    if (day == today.subtract(const Duration(days: 1))) return 'Ieri, $hm';
    return '${DateFormat('d MMM', 'ro').format(t)}, $hm';
  }

  /// „joi, 12 nov · 09:14”
  static String longDate(DateTime t) => '${DateFormat('EEEE, d MMM', 'ro').format(t)} · ${time(t)}';

  static String fileStamp(DateTime t) => DateFormat('yyyy-MM-dd_HH-mm').format(t);

  static DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);
}
