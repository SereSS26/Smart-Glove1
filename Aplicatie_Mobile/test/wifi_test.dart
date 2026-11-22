import 'package:flutter_test/flutter_test.dart';
import 'package:manusa_app/data/settings_store.dart';
import 'package:manusa_app/data/wifi_finder.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('răspunsul mănușii la căutare se citește corect', () {
    final g = WifiFinder.parse('MANUSA Manusa-38E0 192.168.1.37');
    expect(g?.name, 'Manusa-38E0');
    expect(g?.host, '192.168.1.37');
    expect(WifiFinder.parse('MANUSA Manusa-38E0', fallbackHost: '10.0.0.5')?.host, '10.0.0.5');
    expect(WifiFinder.parse('altceva 1.2.3.4'), isNull);
    expect(WifiFinder.parse('MANUSA x nu-e-adresa'), isNull);
  });

  test('adresa scrisă de mână trebuie să fie IPv4', () {
    expect(WifiFinder.isValidHost(' 192.168.1.37 '), isTrue);
    expect(WifiFinder.isValidHost('192.168.1'), isFalse);
    expect(WifiFinder.isValidHost('manusa.local'), isFalse);
  });

  test('cine avea Bluetooth salvat trece pe Wi-Fi, iar adresa rămâne ținută minte', () async {
    SharedPreferences.setMockInitialValues({'dataSource': DataSource.ble.index});
    final store = SettingsStore(await SharedPreferences.getInstance());
    final s = store.load();
    expect(s.source, DataSource.wifi);
    await store.save(s.copyWith(wifiHost: '192.168.1.37', wifiName: 'Manusa-38E0'));
    final again = store.load();
    expect(again.wifiHost, '192.168.1.37');
    expect(again.wifiName, 'Manusa-38E0');
    expect(DataSource.visible, [DataSource.usb, DataSource.wifi, DataSource.demo]);
  });
}
