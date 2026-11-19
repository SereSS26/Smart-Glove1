/// Decide când apare o alertă, fără să știe nimic de ecrane sau notificări (ca să poată fi testat).
///
/// Regula: indicele stă la sau peste prag [holdFor] fără întrerupere; după o alertă urmează o
/// pauză de [cooldown], ca să nu sune telefonul continuu în același episod.
class AlertMonitor {
  AlertMonitor({this.holdFor = const Duration(seconds: 5), this.cooldown = const Duration(seconds: 60)});

  final Duration holdFor;
  final Duration cooldown;

  DateTime? _aboveSince;
  DateTime? _lastAlert;

  /// Primește un eșantion; întoarce true dacă acum trebuie dată o alertă.
  bool onSample(DateTime at, int index, int threshold) {
    if (index < threshold) {
      _aboveSince = null;
      return false;
    }
    _aboveSince ??= at;
    final held = at.difference(_aboveSince!) >= holdFor;
    final rested = _lastAlert == null || at.difference(_lastAlert!) >= cooldown;
    if (held && rested) {
      _lastAlert = at;
      return true;
    }
    return false;
  }

  void reset() {
    _aboveSince = null;
    _lastAlert = null;
  }
}
