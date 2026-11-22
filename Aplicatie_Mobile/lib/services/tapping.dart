import 'dart:math';

/// Rezultatul unui test de tapping.
class TappingResult {
  const TappingResult({required this.taps, required this.rate, required this.amplitude, required this.regularity, required this.fatigue});

  final int taps;

  /// Atingeri pe secundă.
  final double rate;

  /// Cât de larg se deschide și se închide (puncte de îndoire, 0–100). La ecran: 0.
  final double amplitude;

  /// Variația intervalelor dintre atingeri (coeficient de variație, 0 = perfect regulat).
  final double regularity;

  /// Cât scade amplitudinea spre final față de început (0–1); la ecran, cât încetinește ritmul.
  final double fatigue;

  /// „regulat” / „puțin neregulat” / „neregulat”.
  String get rhythmLabel => regularity < 0.15 ? 'ritm regulat' : (regularity < 0.3 ? 'ritm puțin neregulat' : 'ritm neregulat');

  Map<String, num> toMetrics() => {
    'taps': taps,
    'rate': double.parse(rate.toStringAsFixed(2)),
    'amplitude': double.parse(amplitude.toStringAsFixed(1)),
    'regularity': double.parse(regularity.toStringAsFixed(3)),
    'fatigue': double.parse(fatigue.toStringAsFixed(3)),
  };
}

/// Analiza tapping-ului cu mănușa, din îndoirea unui deget (0–100) eșantionată la [hz] pe secundă.
/// Pragurile se adaptează la mâna fiecăruia: o atingere = trecerea peste 65 % din amplitudinea văzută,
/// după ce semnalul a coborât sub 35 % (histerezis, ca tremurul mărunt să nu fie numărat).
/// La 10 eșantioane pe secundă numără sigur până la ~4 atingeri pe secundă.
TappingResult analyzeTapping(List<double> signal, {double hz = 10}) {
  if (signal.length < 4) return const TappingResult(taps: 0, rate: 0, amplitude: 0, regularity: 0, fatigue: 0);
  final lo = signal.reduce(min), hi = signal.reduce(max);
  final span = hi - lo;
  final duration = signal.length / hz;
  if (span < 8) return const TappingResult(taps: 0, rate: 0, amplitude: 0, regularity: 0, fatigue: 0);
  final high = lo + span * 0.65, low = lo + span * 0.35;

  final tapIdx = <int>[];
  final amps = <double>[];
  var armed = signal.first < high;
  var troughMin = signal.first, peakMax = signal.first;
  for (var i = 0; i < signal.length; i++) {
    final v = signal[i];
    if (armed) {
      troughMin = min(troughMin, v);
      if (v >= high) {
        armed = false;
        tapIdx.add(i);
        peakMax = v;
      }
    } else {
      peakMax = max(peakMax, v);
      if (v <= low) {
        armed = true;
        amps.add(peakMax - troughMin);
        troughMin = v;
      }
    }
  }
  if (!armed) amps.add(peakMax - troughMin);

  final intervals = [for (var i = 1; i < tapIdx.length; i++) (tapIdx[i] - tapIdx[i - 1]) / hz];
  return TappingResult(
    taps: tapIdx.length,
    rate: tapIdx.length / duration,
    amplitude: amps.isEmpty ? 0 : amps.reduce((a, b) => a + b) / amps.length,
    regularity: _cv(intervals),
    fatigue: _decrement(amps),
  );
}

/// Analiza tapping-ului pe ecran: momentele atingerilor bune ([times], în secunde) și câte au căzut pe lângă.
TappingResult analyzeScreenTapping(List<double> times, {required double duration, int misses = 0}) {
  final intervals = [for (var i = 1; i < times.length; i++) times[i] - times[i - 1]];
  // La ecran, oboseala = cât cresc intervalele în ultima treime față de prima.
  final third = intervals.length ~/ 3;
  var fatigue = 0.0;
  if (third >= 2) {
    final first = intervals.take(third).reduce((a, b) => a + b) / third;
    final last = intervals.skip(intervals.length - third).reduce((a, b) => a + b) / third;
    fatigue = first <= 0 ? 0 : max(0, 1 - first / last);
  }
  return TappingResult(
    taps: times.length,
    rate: duration <= 0 ? 0 : times.length / duration,
    amplitude: times.isEmpty ? 0 : 100 * times.length / (times.length + misses),
    regularity: _cv(intervals),
    fatigue: fatigue,
  );
}

double _cv(List<double> xs) {
  if (xs.length < 2) return 0;
  final mean = xs.reduce((a, b) => a + b) / xs.length;
  if (mean <= 0) return 0;
  final variance = xs.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b) / xs.length;
  return sqrt(variance) / mean;
}

double _decrement(List<double> amps) {
  final third = amps.length ~/ 3;
  if (third < 1) return 0;
  final first = amps.take(third).reduce((a, b) => a + b) / third;
  final last = amps.skip(amps.length - third).reduce((a, b) => a + b) / third;
  return first <= 0 ? 0 : max(0, 1 - last / first);
}
