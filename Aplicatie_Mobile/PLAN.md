# Plan: aplicația mobilă pentru mănușa de monitorizare a tremorului

## Context
Mănușa (ESP32 + MPU6050 + 5 senzori flex) măsoară deja frecvența și amplitudinea tremorului și îndoirea degetelor ([src/combo5.cpp](../src/combo5.cpp)). Lipsește aplicația de pe telefon, care primește datele prin Bluetooth (BLE), le arată live, înregistrează sesiuni, ține istoricul și produce un raport pentru medic. Planul de mai jos e pentru Artur și se construiește în `/Users/admin/Desktop/Manusa/Aplicatie_Mobile` (folder existent, gol). Urmează cele 5 etape din „Ghid Solo și Artur” și contractul BLE v1 de acolo.

**Decizii luate (răspunsurile tale):**
- Platforme: Android și iPhone. Se lucrează întâi pe Android (uneltele sunt gata pe acest Mac); iPhone se configurează în Etapa 4.
- Utilizatori: pacientul (folosire zilnică, simplă) și un îngrijitor sau medic (istoric și raport).
- Artur programează, dar nu în Flutter: conceptele Flutter sunt explicate pe scurt mai jos.
- Ecranul Live: tremor cu grafic rulant sus, 5 bare pentru degete dedesubt.

**Cum lucrăm:** Claude scrie codul, etapă cu etapă, doar când ceri. Artur rulează aplicația pe telefon, bifează lista „Artur verifică” și decide trecerea la etapa următoare.

## Imagine de ansamblu

### Ce face aplicația
| Zonă | Pentru cine | Ce face |
|---|---|---|
| Live | pacient | Arată tremorul (Hz, indice 0–100, ușor/moderat/puternic) și îndoirea celor 5 degete, în timp real |
| Sesiune | pacient | Înregistrează o perioadă, cu activitate (repaus, postură, acțiune), notă și momente marcate |
| Alerte | pacient | Notificare când tremorul trece de prag; din Etapa 4 vibrează și mănușa |
| Istoric | îngrijitor, medic | Grafic pe zile și săptămâni, lista sesiunilor, detaliile fiecăreia |
| Raport | medic | PDF și CSV trimise din telefon (e-mail, WhatsApp etc.) |
| Calibrare, Conectare, Setări | pacient, îngrijitor | Asociere cu mănușa, calibrare în 3 pași, prag de alertă |

### Harta ecranelor
```
Prima pornire:  Avertisment → Conectare → Calibrare → Live

Bara de jos:    Live ────┬── Sesiune activă
                         └── (cipul de stare) → Conectare
                Istoric ──── Detaliu sesiune ── PDF / CSV
                Setări ──┬── Calibrare
                         ├── Conectare
                         └── Instrucțiuni · Despre
```

### Schițele ecranelor
Sunt schițe de structură. Machetele desenate, cu culori și fonturi, sunt aici: [Machete aplicație Mănușa](https://claude.ai/artifact/TTV5tTJv6wjjNegXhCCNjq).

**1. Live** (varianta aleasă)
```
┌────────────────────────────────┐
│ ● Mănușă conectată         USB │
├────────────────────────────────┤
│ TREMOR                 moderat │
│ 4.6 Hz          indice 62/100  │
│ ▂▃▅▇▅▃▂▃▅▇▅▃▂▃▅▇▅▃  30 s       │
│ stare: repaus                  │
├────────────────────────────────┤
│ DEGETE (îndoire %)             │
│  █                             │
│  █    █                        │
│  █    █    █    ▄              │
│  █    █    █    █    ▄         │
│ Mare Arăt Mijl Inel  Mic       │
│  80   65   40   30   10        │
├────────────────────────────────┤
│ [    ▶  Pornește sesiunea    ] │
├────────────────────────────────┤
│   Live     Istoric    Setări   │
└────────────────────────────────┘
```

**2. Conectare**
```
┌────────────────────────────────┐
│ ←  Conectare                   │
├────────────────────────────────┤
│ Bluetooth: pornit              │
│                                │
│ MĂNUȘI GĂSITE                  │
│ ┌────────────────────────────┐ │
│ │ Manusa-A1F3    semnal ▂▄▆  │ │
│ │             [ Conectează ] │ │
│ └────────────────────────────┘ │
│                                │
│ [       Caută din nou        ] │
│                                │
│ Mod demonstrativ      [oprit]  │
│ (date simulate, fără mănușă)   │
└────────────────────────────────┘
```

**3. Calibrare** (3 pași: mână deschisă, pumn, nemișcat)
```
┌────────────────────────────────┐
│ ←  Calibrare         pasul 1/3 │
├────────────────────────────────┤
│                                │
│   Ține mâna DESCHISĂ,          │
│   cu degetele întinse.         │
│                                │
│         (desen mână)           │
│                                │
│ Stai așa până la confirmare.   │
│                                │
│ [  Salvează „mână deschisă”  ] │
│                                │
│ 1 deschisă · 2 pumn · 3 repaus │
└────────────────────────────────┘
```

**4. Sesiune activă**
```
┌────────────────────────────────┐
│ ● ÎNREGISTRARE           04:12 │
├────────────────────────────────┤
│ 4.6 Hz    indice 62    moderat │
│ ▂▃▅▇▅▃▂▃▅▇▅▃▂▃▅▇▅▃             │
├────────────────────────────────┤
│ Activitate:                    │
│ [Repaus] [ Postură ] [Acțiune] │
│                                │
│ [  + Notă (ex. medicament)   ] │
│ [  ⚑ Marchează un moment     ] │
├────────────────────────────────┤
│ [     ■  Oprește sesiunea    ] │
└────────────────────────────────┘
```

**5. Istoric**
```
┌────────────────────────────────┐
│ Istoric       [Zi] [Săptămână] │
├────────────────────────────────┤
│ Indice de tremor (medie)       │
│ 80│        ▄                   │
│ 60│  ▄     █  ▄                │
│ 40│  █  ▄  █  █     ▄          │
│ 20│  █  █  █  █  ▄  █          │
│   └──L──M──M──J──V──S──D──     │
├────────────────────────────────┤
│ SESIUNI                        │
│ Azi 09:14 · 12 min · repaus    │
│   4.8 Hz · indice 58         › │
│ Ieri 20:30 · 8 min · acțiune   │
│   5.1 Hz · indice 41         › │
├────────────────────────────────┤
│   Live     Istoric    Setări   │
└────────────────────────────────┘
```

**6. Detaliu sesiune și raport**
```
┌────────────────────────────────┐
│ ←  Sesiune · 12 nov, 09:14     │
├────────────────────────────────┤
│ Durată 12 min · repaus         │
│ Frecvență medie         4.8 Hz │
│ Indice mediu / maxim   58 / 81 │
│ Alerte                       2 │
│ ▂▃▅▇▅▃▂▃▅▇▅▃▂▃▅▇▅▃▂▃  (timp)   │
│ Notă: după medicament, ora 9   │
├────────────────────────────────┤
│ [     Trimite raport PDF     ] │
│ [     Exportă date CSV       ] │
└────────────────────────────────┘
```

**7. Setări**
```
┌────────────────────────────────┐
│ Setări                         │
├────────────────────────────────┤
│ Mănușă     Manusa-A1F3 · USB › │
│ Calibrare                    › │
│ Prag alertă     [ − ] 60 [ + ] │
│ Vibrație la alertă    [pornit] │
│ Test vibrație                › │
│ Mod demonstrativ       [oprit] │
│ Instrucțiuni                 › │
│ Despre (nu e dispozitiv        │
│ medical)                     › │
├────────────────────────────────┤
│   Live     Istoric    Setări   │
└────────────────────────────────┘
```

### Reguli de design (utilizatorul are mâna care tremură)
- Butoane înalte de minimum 64 dp, cu spațiu între ele; fără glisări, apăsări lungi sau cursoare. Pragul se schimbă cu `−` și `+`, nu cu un cursor.
- Text de bază de minimum 18 sp; cifrele principale de 56–72 sp.
- Severitatea e mereu culoare **și** cuvânt (ușor / moderat / puternic), nu doar culoare. Pragurile provizorii pe indice sunt sub 30, 30–60, peste 60; se reglează în Etapa 5, după testele cu voluntari.
- Niciodată valori vechi afișate ca live: după 2 secunde fără pachete apare „Fără date” și valorile se estompează.
- Modul demonstrativ afișează permanent banda „DATE SIMULATE”, iar sesiunile simulate sunt marcate și excluse din istoricul real.
- Temă deschisă și întunecată; interfață în română, cu textele într-un singur fișier.
- Avertismentul „nu e dispozitiv medical” apare la prima pornire, în Despre și în subsolul raportului PDF.

## Arhitectură

### Flutter în 7 idei (pentru cine programează, dar nu în Flutter)
| Termen | Ce înseamnă |
|---|---|
| Widget | Orice element de interfață (text, buton, ecran) e o clasă cu metoda `build()` |
| Hot reload | Salvezi fișierul și aplicația de pe telefon se actualizează în ~1 secundă |
| `pubspec.yaml` | Lista de pachete și resurse; pachetele se adaugă cu `flutter pub add nume` |
| `Stream` | Un flux de valori în timp; pachetele BLE vin ca `Stream<LivePacket>` |
| Provider (Riverpod) | Locul unde stă starea aplicației; ecranele îl „ascultă” și se redesenează singure |
| `async` / `await` | Operații care durează (BLE, bază de date) fără să blocheze interfața |
| Generare de cod | `drift` generează codul bazei de date cu `dart run build_runner build` |

### Structura din `Aplicatie_Mobile`
```
lib/
  main.dart, app.dart        pornire, temă, bara de jos cu 3 file
  core/
    contract.dart            UUID-uri, coduri de comandă, lungimea pachetului
    live_packet.dart         modelul pachetului Live + decode(bytes)
    glove_source.dart        interfața comună pentru mănușa reală și cea simulată
    theme.dart, strings.dart culori, dimensiuni, texte în română
  data/
    simulated_glove.dart     date simulate în formatul contractului
    ble_glove.dart           mănușa reală prin BLE (Etapa 2)
    db/                      tabele drift: sesiuni, eșantioane, evenimente (Etapa 3)
    settings_store.dart      prag, ultima mănușă, mod demonstrativ
  features/
    connect/ live/ calibrate/ session/ history/ settings/ onboarding/
  services/
    alert_service.dart       prag, notificare, vibrație
    export_service.dart      CSV și PDF
test/                        teste pentru decodare, simulator, alerte, bază de date
```

Piesa centrală e interfața `GloveSource`. Ecranele nu știu dacă datele vin de la mănușă sau de la simulator, deci tot ce nu ține de Bluetooth se poate construi și testa fără hardware:
```dart
abstract class GloveSource {
  Stream<GloveConnection> get connection;  // deconectat, se conectează, conectat
  Stream<LivePacket> get packets;          // 10 pachete pe secundă
  Future<void> connect(String deviceId);
  Future<void> disconnect();
  Future<void> send(ControlCommand command, [int value = 0]);
}
```

### Pachete
`flutter_riverpod` (stare), `flutter_reactive_ble` + `permission_handler` (BLE), `fl_chart` (grafice), `drift` (bază de date locală), `shared_preferences` (setări), `flutter_local_notifications` (alerte), `pdf` + `share_plus` (raport), `wakelock_plus` (ecran aprins în sesiune), `intl` (date în română). Versiunile se iau la instalare, cu `flutter pub add`. Compatibilitatea lui `flutter_reactive_ble` cu Flutter 3.47.5 nu e verificată; dacă nu merge, se trece la `flutter_blue_plus`, iar schimbarea atinge doar `ble_glove.dart`.

### Date salvate pe telefon
- `sessions`: început, sfârșit, activitate, notă, frecvență medie, indice mediu și maxim, marcaj „simulată”.
- `samples`: un rând pe secundă, cu frecvență, RMS, indice, stare și cele 5 degete.
- `events`: alerte și momente marcate.
- Totul rămâne local. Datele pleacă din telefon doar când utilizatorul trimite un raport. Fără conturi și fără cloud.

### Clarificări de contract propuse (de stabilit cu Solo înainte de Etapa 2)
Contractul v1 lasă trei lucruri nedefinite, iar aplicația are nevoie de ele:
1. **Deget necalibrat:** octetul de îndoire = 255 (ca la baterie, unde 255 = USB). Acum `combo5` folosește −1, care nu încape într-un octet fără semn.
2. **Octetul 13, flaguri:** bit 0 = flexuri calibrate, bit 1 = giroscop calibrat, bit 2 = sesiune activă, bit 3 = buton apăsat de la ultimul pachet.
3. **Confirmarea comenzilor:** contractul nu are răspuns la comenzi. Aplicația confirmă calibrarea citind biții 0 și 1 din flaguri.

## Etape

### Etapa 1 · Fundație și ecranul Live cu date simulate (săpt. 1–2, fără mănușă)
1. Creează proiectul: în `Aplicatie_Mobile`, `flutter create --project-name manusa_app --org ro.manusa --platforms android,ios .`, apoi `flutter run` pe un telefon Android cu „Depanare USB” pornită.
2. Git: `git init` în `/Users/admin/Desktop/Manusa`, `.gitignore` pentru Flutter și `.pio`, branch-urile `solo/hardware` și `artur/app`.
3. `core/contract.dart` și `core/live_packet.dart`, cu teste pe octeți cunoscuți (14 octeți → valorile așteptate; lungime greșită și versiune greșită → eroare).
4. `core/glove_source.dart` și `data/simulated_glove.dart`: 10 pachete pe secundă, episoade de tremor la 4–6 Hz, degete care se mișcă, baterie 255.
5. `core/theme.dart`, `app.dart`: tema și bara de jos cu Live, Istoric, Setări.
6. Ecranul Live după schița 1, alimentat de simulator, cu banda „DATE SIMULATE”.
7. Ecranul Conectare: permisiuni Bluetooth, scanare și lista dispozitivelor găsite; comutatorul „Mod demonstrativ”.

**Artur verifică:** aplicația pornește pe telefon; Live se mișcă fluid; `flutter test` trece; scanarea listează dispozitive BLE din jur.
**Gata când:** Live afișează date simulate pe telefon (poarta din ghid).

### Etapa 2 · Mănușa reală prin BLE (săpt. 3–4, cere firmware-ul BLE)
1. `data/ble_glove.dart`: conectare, abonare la caracteristica Live, decodare, trimitere de comenzi.
2. Stările conexiunii în interfață: deconectat, se conectează, conectat, fără date; reconectare automată.
3. Reține ultima mănușă și se conectează singură la pornire.
4. Ecranul Calibrare după schița 3: trei pași care trimit comenzile 1, 2, 3 și confirmă fiecare pas din flaguri. Contractul nu trimite valori brute, deci ecranul nu arată valori înainte de calibrare.
5. Cipul de alimentare: la 255 afișează „USB”.
6. Test: întâi cu nRF Connect, apoi cu aplicația, 10 minute.

**Artur verifică:** valorile din aplicație se potrivesc cu monitorul serial; după calibrare, mâna deschisă dă ~0 %, pumnul ~100 %; oprești și repornești mănușa, aplicația se reconectează singură.
**Gata când:** 10 minute de date live, fără deconectări, cu mănușa pe mână.

### Etapa 3 · Sesiuni, istoric, raport, alerte (săpt. 5–7, se construiește pe simulator)
1. Baza de date `drift`, cu teste.
2. Sesiunea după schița 4: start, activitate, notă, moment marcat, stop, rezumat; comenzile 4 și 5; ecranul rămâne aprins.
3. Istoric după schița 5 și detaliul sesiunii după schița 6.
4. `export_service.dart`: CSV și raport PDF, trimise prin meniul de partajare al telefonului.
5. `alert_service.dart`: indice peste prag 5 secunde → notificare; pauză de 60 de secunde între alerte; pragul se trimite cu comanda 6.
6. Ecranul Setări după schița 7.

**Artur verifică:** o sesiune apare în Istoric; PDF-ul se deschide și e lizibil; alerta apare când simulatorul trece de prag; sesiunile simulate nu apar în istoricul real.
**Gata când:** o sesiune e salvată și exportată în PDF; o alertă apare ca notificare.

### Etapa 4 · Baterie, vibrație, iPhone (săpt. 8–9, cere hardware-ul nou)
1. Procentul bateriei în cip și avertisment sub 15 %.
2. La alertă, comanda 7 către mănușă; butonul „Test vibrație” în Setări.
3. Reconectarea după repornirea mănușii de pe baterie.
4. iPhone: `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer`, `sudo xcodebuild -runFirstLaunch`, instalare CocoaPods, semnare cu Apple ID, textul de permisiune Bluetooth, rulare pe un iPhone real.

**Artur verifică:** alerta face mănușa să vibreze; aplicația rulează pe ambele telefoane.
**Gata când:** 10 minute de date live de pe baterie; o alertă face mănușa să vibreze.

### Etapa 5 · Prima pornire, finisare, livrare (săpt. 10–11)
1. Fluxul de primă pornire: avertisment → conectare → calibrare.
2. Ecranele Despre și Instrucțiuni; avertismentul în subsolul PDF-ului.
3. Verificare de accesibilitate: text mărit la 130 %, contrast, etichete pentru cititorul de ecran, mărimea butoanelor.
4. Corecturi după testele cu voluntari: pragurile ușor/moderat/puternic și întârzierea alertei.
5. Versiunea finală: `flutter build apk --release`; pe iPhone, rulare în mod release.

**Gata când:** 30 de minute de purtare fără deconectări, pe ambele telefoane; demonstrația finală.

## Ce trebuie să existe în firmware (în afara acestui plan)
| Pentru | Firmware necesar | Stare |
|---|---|---|
| Etapa 2 | mediul `[env:glove]` cu serviciul BLE și pachetul Live la 10 Hz; comenzile 1–3 | nu există încă în [platformio.ini](../platformio.ini) |
| Etapa 3 | FFT cu indicele de tremor; comenzile 4–6 | nu există |
| Etapa 4 | procentul bateriei; comanda 7 | nu există; cere hardware-ul din Etapa 4 |

Etapele 1 și 3 ale aplicației nu depind de mănușă și se pot face una după alta. Etapele 2 și 4 așteaptă firmware-ul și hardware-ul.

## Riscuri
- **Mac cu procesor Intel:** Flutter anunță că renunță la suportul pentru Intel. Nu rula `flutter upgrade` în timpul proiectului.
- **iPhone:** Xcode nu e configurat și CocoaPods lipsește. Cu Apple ID gratuit, aplicația instalată expiră după 7 zile.
- **BLE:** nu merge în emulator sau simulator; orice test de Bluetooth cere telefon real.
- **Înregistrare în fundal:** în prima versiune, sesiunea cere ecranul aprins. Înregistrarea cu telefonul blocat rămâne pentru mai târziu.

## Verificare
- La fiecare etapă: `flutter analyze` fără erori, `flutter test` trecut, apoi lista „Artur verifică” pe telefon.
- Decodarea pachetului se testează pe octeți scriși de mână, aceiași care vor fi folosiți și la testarea firmware-ului.
- Etapa 2: aceleași valori în aplicație, în nRF Connect și în monitorul serial.
- Final: testul de 30 de minute din ghid.

## Stare la 19 noiembrie 2026
Partea de software care nu depinde de mănușă e terminată. Machetele: [Machete aplicație Mănușa](https://claude.ai/artifact/TTV5tTJv6wjjNegXhCCNjq).

| Etapa | Stare |
|---|---|
| 1 · Fundație și Live | gata |
| 2 · Mănușa reală prin BLE | cod scris (`lib/data/ble_glove.dart`), scanarea și permisiunile verificate în emulator; conectarea la mănușă netestată: așteaptă firmware-ul BLE |
| 3 · Sesiuni, istoric, raport, alerte | gata, verificat pe simulator (inclusiv notificarea și PDF-ul) |
| 4 · Baterie, vibrație, iPhone | partea de aplicație scrisă; netestată cu hardware; iPhone neconfigurat (Xcode, CocoaPods) |
| 5 · Prima pornire, finisare | gata: prima pornire, Despre, Instrucțiuni, temă deschisă și întunecată, text mărit la 130 % fără depășiri, APK release. Rămân: pragurile ajustate după testele cu voluntari, testul de 30 de minute cu mănușa |

- 30 de teste automate (`flutter test`): pachetul Live, simulatorul, baza de date, alertele, sesiunea, exportul, desenarea tuturor ecranelor pe ambele teme și cu text mărit.
- Clarificările de contract (deget necalibrat = 255, biții din octetul de flaguri, confirmarea calibrării prin flaguri) sunt deja folosite în `lib/core/contract.dart`; trebuie confirmate cu Solo.
- Proiectul stă pe Desktop, sincronizat cu iCloud. Folderele generate (`build`, `.dart_tool`, `android/.gradle`) sunt legături către variante `.nosync`, pe care iCloud nu le sincronizează; altfel compilarea se blochează.
- APK-ul release e semnat cu cheia de test (debug), bun pentru instalare directă pe telefoane; pentru Google Play trebuie o cheie proprie.
- Git nu e inițializat încă: se face doar la cererea lui Artur.
