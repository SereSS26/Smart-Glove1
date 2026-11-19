import 'package:flutter_test/flutter_test.dart';
import 'package:manusa_app/services/alert_monitor.dart';

void main() {
  final t0 = DateTime(2026, 11, 19, 9);
  DateTime at(double s) => t0.add(Duration(milliseconds: (s * 1000).round()));

  test('alerta apare abia după 5 secunde peste prag', () {
    final m = AlertMonitor();
    expect(m.onSample(at(0), 70, 60), isFalse);
    expect(m.onSample(at(4.9), 70, 60), isFalse);
    expect(m.onSample(at(5.0), 70, 60), isTrue);
  });

  test('o scădere sub prag reia numărătoarea', () {
    final m = AlertMonitor();
    m.onSample(at(0), 70, 60);
    m.onSample(at(3), 50, 60);
    expect(m.onSample(at(6), 70, 60), isFalse);
    expect(m.onSample(at(11), 70, 60), isTrue);
  });

  test('după o alertă urmează o pauză de 60 de secunde', () {
    final m = AlertMonitor();
    m.onSample(at(0), 70, 60);
    expect(m.onSample(at(5), 70, 60), isTrue);
    expect(m.onSample(at(30), 70, 60), isFalse);
    expect(m.onSample(at(64.9), 70, 60), isFalse);
    expect(m.onSample(at(65), 70, 60), isTrue);
  });

  test('indicele egal cu pragul contează ca depășire', () {
    final m = AlertMonitor();
    m.onSample(at(0), 60, 60);
    expect(m.onSample(at(5), 60, 60), isTrue);
  });
}
