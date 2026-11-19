# Mănușa — aplicația mobilă

Aplicația Flutter care primește datele de la mănușa de monitorizare a tremorului (ESP32 + MPU6050 + 5 senzori flex), le arată în timp real, înregistrează sesiuni și pregătește un raport PDF pentru medic. Până există firmware-ul BLE, rulează cu o mănușă simulată (modul demonstrativ). Planul complet și starea lui: [PLAN.md](PLAN.md).

## Rulare

```
cd /Users/admin/Desktop/Manusa/Aplicatie_Mobile
flutter run              # pe emulator sau pe telefonul legat prin USB
flutter test             # testele automate
flutter build apk --release
```

APK-ul release ajunge în `build/app/outputs/flutter-apk/app-release.apk` și se poate instala direct pe orice telefon Android 7+.

În Android Studio: deschide folderul `Aplicatie_Mobile`, alege emulatorul sau telefonul și apasă **Run**.

## Structura

| Folder | Ce conține |
|---|---|
| `lib/core/` | contractul BLE, pachetul Live (14 octeți), tema, textele, formatările |
| `lib/data/` | mănușa simulată, mănușa BLE, baza de date locală, setările, datele demo |
| `lib/state/` | starea aplicației (Riverpod): conexiunea, datele live, sesiunea, alertele |
| `lib/services/` | regula de alertă, notificările, exportul PDF/CSV |
| `lib/features/` | ecranele: prima pornire, Live, Sesiune, Istoric, Detaliu, Conectare, Calibrare, Setări |
| `test/` | testele automate |

## Mănușa reală

Firmware-ul mănușii e `../src/glove.cpp` (mediul PlatformIO `glove`). Trimite pachetul Live din contract (`lib/core/contract.dart`) pe USB și prin Bluetooth, 10 pe secundă.

**Prin USB (mănușa legată la calculator):**
1. Urcă firmware-ul: în folderul `Manusa`, `~/.platformio/penv/bin/pio run -e glove -t upload`.
2. Închide monitorul serial și pornește puntea: `~/.platformio/penv/bin/python tools/usb_bridge.py` (lasă terminalul deschis).
3. În aplicație: Setări › Sursa datelor › **USB**. Puntea face singură `adb reverse` către emulator sau telefonul legat prin cablu (portul 8765).
4. Calibrează degetele din Live › Calibrează acum.

**Prin Bluetooth (telefon real):** Setări › Sursa datelor › **Bluetooth**, apoi Setări › Mănușă › Conectează. Mănușa se anunță ca `Manusa-XXXX`.

## De știut

- Proiectul stă pe Desktop, sincronizat cu iCloud. `build`, `.dart_tool` și `android/.gradle` sunt legături către foldere `.nosync`, ca iCloud să nu blocheze compilarea. Nu le înlocui cu foldere obișnuite.
- Aplicația nu este dispozitiv medical; valorile sunt orientative.
