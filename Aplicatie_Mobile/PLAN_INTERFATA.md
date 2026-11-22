# Plan: aspectul nou al aplicației — autentificare, pacient și medic

## Stare (21 noiembrie 2026)
Toate cele 10 etape (0–9) sunt făcute în cod: `flutter analyze` nu are probleme, iar cele 102 teste automate trec. Aplicația rulează în emulator.

| Etapă | Ce s-a făcut |
|---|---|
| 0–4 | machetele, sistemul de design, autentificarea și rolurile, Live cu Wi-Fi, testele ghidate |
| 5 | Istoric pe Zi / Săptămână / Lună, procente, timp peste prag, calendar, PDF |
| 6 | Remindere: dozele de azi, „Am luat” (cu anulare) / „Amână 10 min” și din notificare, stocul, avertismentul de stoc mic, reminderul de test, notificări la ora exactă |
| 7 | scanarea rețetei (ML Kit, pe telefon), importul din notițe, „Trimite către Mănușa”, ecranul „Verifică medicamentele” |
| 8 | medicul: Pacienți (de urmărit, cu motiv), detaliul pacientului (Prezentare / Sesiuni / Medicație, 7 / 30 / 90 de zile), Rapoarte PDF / CSV, rezumatul de luni |
| 9 | inelul animat (oprit la „Reducere animații”), vibrația la apăsare și ghidarea vocală (Setări › Aspect), două coloane pe tabletă, capturile automate (`flutter test tool/screenshots_test.dart` → `screenshots/`) |

**Rămâne de verificat pe telefon** (nu se poate testa automat):
- un reminder pus peste 2 minute sună și cu ecranul blocat;
- o rețetă tipărită, fotografiată;
- mănușa reală prin Wi-Fi, 10 minute;
- 20 de atingeri la tapping.

Supabase vine după autorizarea conectorului din `/mcp`.

## Context
Aplicația merge funcțional: Live, sesiuni, istoric, alerte și date reale de la mănușă prin USB. Arată însă ca un prototip: paleta albastră din machetele vechi, un singur utilizator, 3 file. Acum vrei un aspect profesionist și prietenos, în roz medical, cu autentificare pe tot ecranul și două roluri:
- **Pacientul**: Live cu alegerea conexiunii (USB, Wi-Fi, Demo) și calibrare; sesiuni cu teste ghidate de tremor și tapping; Istoric pe zi, săptămână și lună, cu procente și pragul; o filă nouă de Remindere, cu medicamente, stoc și scanarea rețetei; Setări.
- **Medicul**: pacienții lui, istoricul și graficele lor, exportul rezultatelor, Setări.

Autentificarea e scrisă în cod acum. Supabase sau Firebase vin mai târziu, în spatele acelorași interfețe, deci ecranele nu se refac.

## Decizii
| Subiect | Decizie |
|---|---|
| Conexiunea fără fir | **Wi-Fi în loc de Bluetooth** (alegerea ta). Pe Live: USB · Wi-Fi · Demo. Codul Bluetooth rămâne în aplicație, ascuns; în firmware se oprește dintr-un comutator. |
| Rolurile | Rolul vine din cont, ca mai târziu în Supabase, nu dintr-un comutator pe ecranul de intrare. |
| Conturile demo | `pacient@manusa.ro` / `pacient123` (Ion Popescu, 68 de ani) și `medic@manusa.ro` / `medic123` (Dr. Andreea Pavel, neurolog). Se schimbă dintr-un singur fișier. |
| Pacienții medicului | 4 pacienți fictivi, plus Ion Popescu cu datele reale de pe telefon: o sesiune făcută ca pacient apare imediat la medic. |
| Scanarea rețetei | Pe telefon, fără internet (Google ML Kit). Nimic nu se salvează fără ecranul de verificare. |
| Graficele | Extind graficele desenate deja în cod (`features/history/charts.dart`, `features/live/sparkline.dart`), fără bibliotecă nouă. |
| Numele | Rămâne „Mănușa”, cu o siglă nouă. |

## 1. Direcția de design
Ideea: o clinică luminoasă și caldă. Fundal alb cald, roz pentru acțiuni și accente, text prună foarte închis în loc de negru. Aspectul premium vine din spațiu, cifre mari, umbre moi și mișcare discretă, nu din decor.

### Paleta (se validează în machete)
| Rol | Temă deschisă | Temă întunecată |
|---|---|---|
| Fundal | `#FBF6F8` alb cald | `#140D11` prună-negru |
| Card | `#FFFFFF` | `#1E1419` |
| Text / text secundar | `#24151D` / `#6B5562` | `#F7EAF0` / `#BFA3B1` |
| Roz principal (butoane) | `#D6336C`, text alb, contrast 4,6:1 | `#F06C9B`, text închis, contrast 6:1 |
| Roz închis (titluri, selecție) | `#A3214F` | `#FFB3CC` |
| Roz pal (fundal activ) | `#FCE7EF` | `#3A1A28` |
| Degradeu (butonul principal, antete) | `#E8508A` → `#B8285F` | `#C2386F` → `#7A1F47` |
| Margini | `#F1DFE7` | `#3A2830` |

- **Severitatea** are culori proprii, pe ambele teme: ușor = mentă `#2F9E77`, moderat = chihlimbar `#E8A33D`, puternic = roșu `#D92D3A`. Apare mereu cu cuvânt și semn (▲), nu doar cu culoare. Roșul nu se folosește pentru brand, iar rozul nu se folosește pentru alerte.
- Păstrez numele din `AppColors` (`accent`, `accentSoft`…), ca ecranele existente să ia singure culorile noi. Adaug doar ce lipsește: degradeul, umbra, cardul ridicat.

### Tipografie, forme, mișcare
- **Font**: Atkinson Hyperlegible Next, varianta nouă a fontului actual, cu mai multe grosimi. Cifrele live au 64–72, sunt foarte groase și au lățime fixă, ca să nu „sară”. Titluri 30; text 18 la pacient și 16 la medic; etichete 14, cu majuscule rărite.
- **Forme**: carduri cu colțuri de 24, butoane de 20, pastile complet rotunde. Pe tema deschisă, umbre moi rozalii în loc de margini; pe cea întunecată, margini fine.
- **Mișcare**: 200–300 ms, lin. Cifrele se schimbă rostogolindu-se, inelul se umple treptat. Totul se oprește dacă telefonul are „Reducere animații”.
- **Vibrație la apăsare**: un puls scurt confirmă fiecare apăsare importantă, util când mâna tremură. Se poate opri din Setări.
- **Iconițe**: Material Symbols Rounded, pline când sunt selectate.
- **Ilustrații** desenate în cod, în culorile temei, deci arată bine și pe tema întunecată: mâna, pozițiile pentru teste, stările goale.
- **Sigla**: o palmă stilizată cu o linie de puls; iconiță Android și ecran de pornire în roz.

### Reguli pentru pacient (rămân)
Butoane de minimum 64 dp; text de minimum 18; fără glisări sau apăsări lungi ca singură cale; valorile se schimbă cu `−`/`+`, nu cu cursoare; „Fără date” după 2 s; totul merge cu textul mărit la 130 %. În plus: după acțiunile care contează („Am luat”, „Oprește”) ai 5 secunde să anulezi, ca o apăsare greșită să nu strice nimic.

### Piesele noi de interfață (`lib/ui/`)
| Piesă | Ce face | Unde |
|---|---|---|
| `GradientButton` | buton principal cu degradeu și vibrație | Intră, Pornește o sesiune, Am luat |
| `TremorRing` | inel 0–100 în culoarea severității, cu semn la prag | Live, teste, rezultate |
| `LiveHand` | mână desenată; fiecare deget se umple după îndoire, cele necalibrate apar punctate | Live, calibrare, tapping |
| `TrendChart` | linie cu arie, banda pragului, semne pentru doze | Live, Istoric, Medic |
| `PeriodBars` | bare pe ore sau zile, cu pragul punctat | Istoric, Medic |
| `MonthHeatmap` | calendarul lunii, fiecare zi colorată după indice | Istoric (Lună), Medic |
| `MetricTile` + `DeltaBadge` | cifră mare + „▼ 12 % · mai bine” | Istoric, rezultate, Medic |
| `ChoiceTiles` | plăci mari cu iconiță (USB, Wi-Fi, Demo) | Live, Setări, prima pornire |
| `StepperField` | `−` valoare `+`, fără tastatură | prag, doză, stoc |
| `DoseTile`, `StockBar` | rândul unei doze cu „Am luat”; bara stocului cu zilele rămase | Remindere |
| `PatientCard` | inițiale, mini-grafic, indice, tendință, aderență | Medic |
| `EmptyState` | ilustrație + o propoziție + un buton | liste goale |

`AppCard`, `SeverityChip`, `BackHeader`, `SimulatedBanner` și `FillOrScroll` din `core/widgets.dart` rămân, restilizate.

## 2. Harta aplicației
```
Pornire → ecranul de pornire → Autentificare
            ├─ pacient → (prima dată: Avertisment → Notificări → Mănușa) → aplicația pacientului
            └─ medic   → aplicația medicului

Pacient, bara de jos: Live · Istoric · Remindere · Setări
  Live ── Calibrare
       └─ Pornește o sesiune → Ce verificăm azi? → Test pas cu pas → Rezultat
                                                └─ Înregistrare liberă (ecranul de acum)
  Istoric ── Detaliu sesiune / evaluare ── PDF · CSV
  Remindere ── Adaugă: Scanează rețeta · Importă din notițe · Manual · Reminder de test
            ├─ Verifică medicamentele (după scanare sau import)
            └─ Detaliu medicament (program, stoc, doze luate)
  Setări ── Profil · Mănușa · Alerte · Notificări · Aspect · Date · Ieși din cont

Medic, bara de jos: Pacienți · Rapoarte · Setări
  Pacienți ── Detaliu pacient (Prezentare · Sesiuni · Medicație) ── Exportă
  Rapoarte ── alegi pacienții, perioada și formatul → trimiți
```

## 3. Ecranele pacientului

### 3.1 Autentificare
```
┌──────────────────────────────────┐
│  fundal roz în degradeu, cu pete │
│  de lumină care se mișcă încet   │
│                                  │
│            ( sigla )             │
│              Mănușa              │
│  Tremorul tău, urmărit cu grijă  │
│                                  │
│ ┌──────────────────────────────┐ │
│ │ Bine ai venit                │ │
│ │ E-mail  [                  ] │ │
│ │ Parolă  [ ••••••••       ◉ ] │ │
│ │ [x] Ține-mă minte            │ │
│ │ [          Intră           ] │ │
│ │ Conturi demo:                │ │
│ │ [   Pacient  ]  [   Medic  ] │ │
│ └──────────────────────────────┘ │
│     Nu este dispozitiv medical   │
└──────────────────────────────────┘
```
- Câmpuri mari (64 dp), tastatură de e-mail, „Enter” trece la parolă, ochi pentru afișarea parolei. Greșelile apar clar sub câmp: „E-mailul sau parola nu se potrivesc”.
- „Ține-mă minte” e pornit implicit: la următoarea pornire intri direct.
- Butoanele „Conturi demo” completează și intră dintr-o apăsare. Dispar odată cu Supabase.
- „Ai uitat parola?” și „Creează cont” apar abia cu Supabase, ca să nu existe butoane care nu fac nimic.

### 3.2 Live
```
┌──────────────────────────────────┐
│ Bună, Ion                   (IP) │
│ sâmbătă, 21 noiembrie            │
│ ┌ MĂNUȘA ──────── ● conectată ─┐ │
│ │ [  USB  ] [ Wi-Fi ] [ Demo ] │ │
│ │ [ Calibrează mănușa      › ] │ │
│ └──────────────────────────────┘ │
│ [ ►     Pornește o sesiune     ] │
│ ┌ TREMOR ─────────── moderat ──┐ │
│ │   ╭────╮                     │ │
│ │   │ 62 │   4,6 Hz            │ │
│ │   ╰────╯   pragul tău: 60    │ │
│ │ ▂▃▅▇▅▃▂▃▅▇▅▃ - - prag - 30 s │ │
│ └──────────────────────────────┘ │
│ ┌ DEGETE ──────────────────────┐ │
│ │  mâna desenată: degetele se  │ │
│ │  umplu cu roz după îndoire   │ │
│ │  Mare 80  Arătător 65  ...   │ │
│ │ ∿∿∿∿∿∿∿∿∿∿  ultimele 30 s    │ │
│ └──────────────────────────────┘ │
├──────────────────────────────────┤
│ Live  Istoric  Remindere  Setări │
└──────────────────────────────────┘
```
- Sus: salutul cu numele și data; avatarul duce la Profil. În Demo apare banda „DATE SIMULATE”.
- **Cardul Mănușa**: starea conexiunii, plăcile USB / Wi-Fi / Demo, butonul „Calibrează mănușa” (cu data ultimei calibrări), bateria sau „USB”. Dacă pe Wi-Fi nu e găsită nicio mănușă, cardul arată „Caută mănușa”.
- **„Pornește o sesiune”** e butonul mare cu degradeu. În timpul unei înregistrări devine „Înregistrare în curs · 04:12” și te duce înapoi la ea.
- **Tremor**: inelul cu indicele și cuvântul, frecvența în Hz, graficul ultimelor 30 s cu pragul tău. Zona de peste prag e colorată.
- **Degete**: mâna desenată, valorile și graficul ultimelor 30 s pentru degetele calibrate (acum F1 și F2).
- Ecranul încape fără derulare la text normal și devine derulabil la 130 % (`FillOrScroll`, ca acum).

### 3.3 Sesiunea: teste ghidate
```
┌──────────────────────────────────┐   ┌──────────────────────────────────┐
│ ←  Ce verificăm azi?             │   │ Evaluare · pasul 2 din 4       × │
├──────────────────────────────────┤   │ ●●○○                             │
│ ┌──────────────────────────────┐ │   ├──────────────────────────────────┤
│ │ EVALUARE COMPLETĂ            │ │   │ Tremor postural                  │
│ │ 4 teste · aproximativ 3 min  │ │   │ Ține brațul întins în față,      │
│ │ ultima: ieri, tremor 48      │ │   │ cu palma în jos.                 │
│ │ [          Începe          ] │ │   │   (desen: braț întins)           │
│ └──────────────────────────────┘ │   │            ╭────────╮            │
│ SAU UN SINGUR TEST               │   │            │  18 s  │            │
│ Tremor în repaus          30 s › │   │            ╰────────╯            │
│ Tremor postural           30 s › │   │   inelul se golește în 30 s      │
│ Tremor în mișcare         30 s › │   │ acum: indice 54 · moderat        │
│ Tapping cu mănușa         15 s › │   │ Auzi un semnal la final.         │
│ Tapping pe ecran          20 s › │   │ [          ■  Oprește          ] │
│ Înregistrare liberă   cât vrei › │   └──────────────────────────────────┘
└──────────────────────────────────┘
```

| Test | Ce faci | Durată | Ce măsoară |
|---|---|---|---|
| Tremor în repaus | mâna relaxată pe genunchi | 30 s | indicele mediu și maxim, frecvența |
| Tremor postural | brațul întins în față, palma în jos | 30 s | la fel, comparat cu repausul |
| Tremor în mișcare | atingi vârful nasului cu arătătorul, apoi întinzi brațul, rar | 30 s | indicele în mișcare, frecvența |
| Tapping cu mănușa | atingi degetul mare cu arătătorul, repede și larg | 15 s | atingeri pe secundă, amplitudinea, regularitatea, oboseala (amplitudinea la final față de început) |
| Tapping pe ecran | atingi pe rând două cercuri mari; merge și fără mănușă | 20 s | atingeri pe secundă, ritmul, atingerile pe lângă |

- **Evaluarea completă** înseamnă primele 4 teste la rând, cam 3 minute. E testul zilnic recomandat, la care trimit și reminderele.
- **Pașii**: instrucțiune cu desen și text mare (opțional citită cu voce) → „Încep” → numărătoare 3-2-1 cu vibrații → înregistrare cu inel de timp → semnal sonor și vibrație la final, pentru că la testul postural nu te uiți la ecran → rezultatul pasului. Un pas se poate reface, iar „Oprește” merge oricând.
- **Rezultatul**: tremorul (0–100 și cuvântul) și tapping-ul (atingeri pe secundă), fiecare cu diferența față de evaluarea anterioară. Urmează două întrebări opționale, cu butoane mari: „Ai luat medicamentul azi?” și „Cum te simți?”. Nu inventez un scor clinic combinat.
- **„Înregistrare liberă”** e sesiunea de acum (activitate, notă, moment marcat), în noul aspect.

### 3.4 Istoric
```
┌──────────────────────────────────┐
│ Istoric                          │
│ [   Zi   ][ Săptămână ][  Lună  ]│
│ ‹      10 – 16 noiembrie       › │
├──────────────────────────────────┤
│ Media      42   ▼ 12 % mai bine  │
│ Peste prag 8 % din timp (prag 60)│
│ Aderență   92 %     Teste 5 din 7│
├──────────────────────────────────┤
│ 80│        ▄                     │
│ 60│- - - - █ - - - - - - - prag  │
│ 40│ ▄  ▄   █  ▄     ▄            │
│ 20│ █  █   █  █  ▄  █  ▄         │
│   └─L──M───M──J──V──S──D──       │
│   - - - = pragul tău (60)        │
├──────────────────────────────────┤
│ TAPPING   3,2 atingeri/s   ▲ 6 % │
│ ∿∿∿∿∿∿∿∿∿∿∿∿  evoluția pe teste  │
├──────────────────────────────────┤
│ SESIUNI [Toate][Evaluări][Libere]│
│ Azi 09:14 · evaluare · 48      › │
│ Ieri 20:30 · liberă · 8 min    › │
└──────────────────────────────────┘
```
- **Zi / Săptămână / Lună**, cu săgeți ‹ › între perioade și „Azi” pentru întoarcere; fără glisări.
- **Cifrele perioadei**:
  - media indicelui, cu procentul față de perioada anterioară („▼ 12 % · mai bine”);
  - timpul peste prag, în % din timpul înregistrat;
  - vârful;
  - aderența la medicamente;
  - testele făcute.
- **Graficul**:
  - pe Zi, linia pe ore, cu pragul și semne la dozele luate, ca să se vadă efectul medicamentului;
  - pe Săptămână, bare pe zile;
  - pe Lună, calendarul colorat plus barele pe 30 de zile, cu media pe 7 zile.
- **Tapping**: atingerile pe secundă din teste, în timp.
- **Perspective** (propunerea mea): una sau două observații din datele tale, de exemplu „Seara, tremorul e cu 23 % mai mare decât dimineața” sau „În cele 2 ore după Madopar, indicele scade în medie cu 18 %”. Sunt observații, nu sfaturi medicale.
- **Sesiunile** se filtrează în Toate / Evaluări / Libere. „Trimite raportul perioadei” face un PDF.
- Procentul se calculează așa: (media acum − media înainte) ÷ media înainte. La tremor, minus înseamnă „mai bine”. Dacă perioada anterioară nu are date, scrie „fără comparație”.

### 3.5 Remindere și medicamente (filă nouă)
```
┌──────────────────────────────────┐
│ Remindere           [ + Adaugă ] │
├──────────────────────────────────┤
│ AZI · 3 din 5 făcute             │
│ 08:00 ✓ Madopar 250 mg · 1 cp    │
│ 09:00 ✓ Test de tremor           │
│ 14:00 ● Madopar 250 mg · 1 cp    │
│         [      Am luat       ]   │
│ 20:00 ○ Madopar 250 mg · 1 cp    │
│ 22:00 ○ Rivotril 0,5 mg · ½ cp   │
├──────────────────────────────────┤
│ MEDICAMENTELE MELE               │
│ Madopar 250 mg  ▓▓▓░░░  12 buc.  │
│ ajunge 4 zile    [Am cumpărat]   │
│ Rivotril 0,5 mg ▓▓▓▓▓▓  28 buc.  │
├──────────────────────────────────┤
│ ALTE REMINDERE                   │
│ Test zilnic la 09:00    [pornit] │
└──────────────────────────────────┘
```
- Totul stă pe o singură pagină, fără sub-file ascunse:
  - **Azi**: dozele și testele zilei, cu „Am luat” sau „Fă testul”;
  - **Medicamentele mele**: stocul și „Am cumpărat”;
  - **Alte remindere**: fiecare cu comutatorul lui.
- Fiecare medicament are o culoare și o formă de pastilă alese de tine, ca să-l recunoști ușor pe ecran.
- **Stocul**: consumul pe zi = doza × de câte ori pe zi; zilele rămase = stocul ÷ consumul pe zi. „Am luat” scade doza din stoc (cu anulare 5 s). „Am cumpărat” adaugă o cutie sau o cantitate aleasă cu `−`/`+`.
- **Notificări**:
  - doza: „E ora pentru Madopar 250 mg · 1 comprimat”, cu butoanele „Am luat” și „Amână 10 min” direct în notificare;
  - testul: „E timpul pentru testul de azi (3 min)”; deschide direct evaluarea;
  - stocul: „Mai ai Madopar pentru 4 zile. Cumpără o cutie.” Vine o dată pe zi, de la pragul ales (implicit 5 zile);
  - doza ratată (opțional): după o oră fără „Am luat”.
- **Adaugă** deschide o foaie cu 5 opțiuni mari: Scanează rețeta · Importă din notițe · Adaugă manual · Reminder de test · Alt reminder.

**Scanarea și importul**
- *Scanează*: camera sau o poză din galerie → ML Kit citește textul pe telefon → analizorul de mai jos.
- *Importă*: un câmp mare cu butonul „Lipește”. Sau, din Notițe, WhatsApp ori Keep: „Trimite către Mănușa”.
- *Analizorul* (reguli scrise pentru română) recunoaște:
  - numele și concentrația (mg, g, mcg, ml, UI);
  - doza (1 cp, ½ cp, 2 capsule);
  - orarul („1-0-1”, „de 3 ori pe zi”, „dimineața / la prânz / seara / la culcare”, „la 8”, „08:00”);
  - cantitatea din cutie („30 cp”);
  - durata („10 zile”).
```
┌──────────────────────────────────┐
│ ←  Am găsit 2 medicamente        │
├──────────────────────────────────┤
│ Verifică fiecare rând cu rețeta. │
│ ┌──────────────────────────────┐ │
│ │ [x] Madopar 250 mg           │ │
│ │ Doză   [ − ]  1 cp  [ + ]    │ │
│ │ Ore    [08:00][14:00][20:00] │ │
│ │ Stoc   [ − ]  30    [ + ]  ! │ │
│ └──────────────────────────────┘ │
│ ┌──────────────────────────────┐ │
│ │ [x] Propranolol 40 mg        │ │
│ │ citit „1-0-1”: 08:00 și 20:00│ │
│ └──────────────────────────────┘ │
│ ! = verifică, citit nesigur      │
│ [    Salvează 2 medicamente    ] │
└──────────────────────────────────┘
```
- Ecranul de verificare are câte un card pe medicament, cu `−`/`+` și ore gata făcute: Dimineața 08:00, Prânz 14:00, Seara 20:00, Culcare 22:00, Altă oră. Câmpurile citite nesigur sunt marcate. Sus scrie: „Aplicația poate citi greșit. Verifică întotdeauna cu rețeta.”

### 3.6 Setări
- **Profil**: nume, e-mail, „Medicul meu: Dr. Andreea Pavel”, codul de pacient (pentru legarea de medic, cu Supabase).
- **Mănușa**: sursa datelor (USB / Wi-Fi / Demo), adresa Wi-Fi și „Pune mănușa pe Wi-Fi”, calibrarea, testul de vibrație.
- **Alerte**: pragul (`−`/`+`), vibrația la alertă.
- **Notificări**: medicamente, teste, stoc, alerte de tremor; cu câte zile înainte anunță stocul.
- **Aspect**: tema (Sistem / Deschisă / Întunecată), vibrația la apăsare, ghidarea vocală în teste.
- **Date**: date demo, exportul tuturor datelor (CSV), ștergerea datelor.
- Instrucțiuni · Despre (nu este dispozitiv medical) · **Ieși din cont**.

## 4. Ecranele medicului
Același design, dar mai dens, pentru că medicul nu are tremor: text 16, butoane de 48 dp.

### 4.1 Pacienți
```
┌──────────────────────────────────┐
│ Bună dimineața,             (AP) │
│ Dr. Andreea Pavel                │
│ [ 5 pacienți ]  [ 2 de urmărit ] │
│ [ Caută pacient...             ] │
├──────────────────────────────────┤
│ NECESITĂ ATENȚIE                 │
│ (MI) Maria Ionescu, 72 ani       │
│      ∿∿∿∿∿∿  58 moderat  ▲ 18 %  │
│      peste prag de 3 ori azi   › │
│ (GD) Gheorghe Dumitru, 65 ani    │
│      ∿∿∿∿∿∿  44 moderat          │
│      aderență 78 %             › │
│ CEILALȚI                         │
│ (IP) Ion Popescu, 68 ani         │
│      date de pe acest telefon  › │
├──────────────────────────────────┤
│   Pacienți   Rapoarte   Setări   │
└──────────────────────────────────┘
```
- Sus: un rezumat (câți pacienți, câți sunt de urmărit) și căutarea. În listă, pacienții care necesită atenție apar primii.
- Fiecare card spune *de ce* e pacientul de urmărit: „peste prag de 3 ori azi”, „indice ▲ 18 % în 7 zile”, „aderență 78 %”, „fără date de 3 zile”.

### 4.2 Detaliul pacientului
```
┌──────────────────────────────────┐
│ ←  Maria Ionescu     [ Exportă ] │
│    72 ani · tremor esențial      │
│ [Prezentare][Sesiuni][Medicație] │
│ [ 7 zile ][ 30 zile ][ 90 zile ] │
├──────────────────────────────────┤
│ Media 58  ▲ 18 % față de luna    │
│ trecută · peste prag 21 % din    │
│ timp · aderență 85 %             │
│ (grafic 30 de zile cu pragul)    │
│ (calendarul lunii: fiecare zi    │
│  colorată după indice)           │
│ Tapping 2,4 atingeri/s  ▼ 9 %    │
└──────────────────────────────────┘
```
- **Prezentare**: perioada (7 / 30 / 90 de zile), cifrele cu procente, graficul cu pragul, calendarul, tapping-ul, perspectivele. Refolosește piesele din Istoric.
- **Sesiuni**: sesiunile și evaluările pacientului. Se deschid în aceleași ecrane de detaliu ca la pacient, doar pentru citire.
- **Medicație**: medicamentele, aderența pe zile (calendar cu bife) și stocul.
- **Exportă**: PDF (raport cu grafice) sau CSV (date), pe perioada aleasă.

### 4.3 Rapoarte
Alegi pacienții (cu bife), perioada (7 / 30 / 90 de zile sau alta), formatul (PDF / CSV) și ce include (grafice, sesiuni, teste, medicație), apoi apeși „Generează și trimite”. Meniul de partajare primește câte un fișier pentru fiecare pacient.

### 4.4 Setări
- **Profil**: nume, specialitate, clinică.
- **Notificări**: rezumatul săptămânal, luni la 09:00, făcut din datele de pe telefon. Alertele imediate despre pacienți vin odată cu Supabase.
- **Export**: formatul și perioada implicite.
- Tema · Despre · **Ieși din cont**.

## 5. Ce se schimbă în cod

**Autentificarea** urmează modelul lui `GloveSource`: ecranele nu știu de unde vin datele.
```dart
abstract class AuthRepository {
  Stream<AppUser?> get user;                              // null = neautentificat
  Future<AppUser> signIn(String email, String password);  // eroare cu mesaj în română
  Future<void> signOut();
}
// Acum: HardcodedAuth, cu cele 2 conturi demo. Cu Supabase: SupabaseAuth. Ecranele rămân la fel.
```
- `AppUser` are id, nume, e-mail și rol (pacient sau medic). Contul ales se ține în `SharedPreferences`.
- `AuthGate` înlocuiește `home:` din `app.dart`: ecranul de pornire → Autentificare → `PatientShell` (4 file) sau `DoctorShell` (3 file). `HomeShell` din `app.dart` devine `PatientShell`, iar alertele de tremor rămân acolo.
- Medicul citește datele prin `ClinicRepository`: lista pacienților și istoricul unui pacient pe o perioadă.
  - Acum îl implementează `DemoClinic`: 4 pacienți generați la fel la fiecare pornire, pe 90 de zile, plus Ion Popescu din baza locală.
  - Cu Supabase vine `SupabaseClinic`.

**Baza de date v2** (`data/db/app_database.dart`, migrare de la v1, cu test):
- `sessions` primește `user_id` (sesiunile vechi trec la Ion Popescu) și `kind` (liberă / evaluare / test);
- `test_results`: testul, rezultatul principal, măsurătorile (JSON), traseul tapping-ului la 10 valori pe secundă;
- `medications`, `intakes` (dozele programate și ce s-a întâmplat cu ele), `stock_events` (cumpărat / luat), `reminders`.

**Wi-Fi**
- *Firmware* (`src/glove.cpp`):
  - mănușa intră în rețeaua de acasă sau în hotspotul telefonului, deci merge și în afara casei; datele rețelei rămân salvate în ea;
  - un server TCP pe portul 8765 vorbește exact ca puntea USB (`P <hex>`, `C <cod> <valoare>`);
  - răspunde la căutare pe UDP 8766, cu numele și adresa;
  - își scrie adresa IP pe USB;
  - Bluetooth trece în spatele unui comutator `GLOVE_BLE` din `platformio.ini`, oprit, ceea ce eliberează memorie.
- *Rețeaua mănușii se setează* cu comanda `W <rețea>;<parolă>` trimisă pe USB, din monitorul serial sau din aplicație (Setări › Mănușa › Pune mănușa pe Wi-Fi, cât timp mănușa e pe USB). Puntea `tools/usb_bridge.py` lasă să treacă și liniile `W`.
- *Aplicația*:
  - `UsbGlove` (`data/usb_glove.dart`) devine `TcpGlove`, cu adresă configurabilă: USB = 127.0.0.1, Wi-Fi = adresa mănușii;
  - `WifiFinder` trimite „MANUSA?” în rețea și listează răspunsurile; adresa se poate scrie și de mână;
  - `DataSource.wifi` se adaugă la sfârșitul enum-ului din `data/settings_store.dart`, ca setările salvate să rămână valide; cine avea Bluetooth salvat trece pe Wi-Fi;
  - ecranul Conectare (`features/connect/`) are secțiunile USB, Wi-Fi și Demo; partea de Bluetooth e ascunsă.

**Testele**
- Detectorul de tapping (`features/tests/tapping_detector.dart`) citește arătătorul (F2), sau degetul mare dacă arătătorul nu e calibrat. Pragurile lui se adaptează la mâna ta. Numără închiderile și calculează ritmul, amplitudinea, regularitatea și oboseala. La 10 pachete pe secundă numără sigur până la vreo 4 atingeri pe secundă, cât fac majoritatea pacienților.
- `LiveState` (`state/providers.dart`) ține și ultimele 30 s ale degetelor, pentru graficul de pe Live și pentru tapping.
- Simulatorul (`data/simulated_glove.dart`) primește câte un scenariu pentru fiecare test: postural cu mai mult tremor, tapping de ~3 atingeri pe secundă cu oboseală. Așa, totul se poate încerca în Demo.

**Notificările programate** (`services/notification_service.dart` extins + `services/reminder_scheduler.dart` nou):
- se programează la ora locală (`timezone`);
- canale separate pentru Medicamente, Teste, Stoc și Alerte de tremor (canalul de acum);
- se reprogramează la pornire, la orice modificare și după repornirea telefonului;
- „Am luat” și „Amână” merg și cu aplicația închisă;
- permisiunea pentru ora exactă se cere la primul reminder, cu un ecran care explică de ce.

**Datele demo** (`data/demo_seed.dart`) acoperă 90 de zile în loc de 7, cu evaluări, medicamente și doze, ca toate graficele și procentele să aibă ce arăta.

**Fișiere noi, pe scurt**
```
lib/auth/                  app_user.dart, auth_repository.dart, hardcoded_auth.dart
lib/ui/                    tokens.dart (culori, spații, umbre, text) + components/ (piesele noi)
lib/features/auth/         splash_screen.dart, login_screen.dart
lib/features/shell/        auth_gate.dart, patient_shell.dart, doctor_shell.dart
lib/features/tests/        test_picker_screen.dart, test_runner_screen.dart, test_result_screen.dart,
                           tapping_detector.dart, screen_tapping_test.dart
lib/features/reminders/    reminders_screen.dart, add_sheet.dart
lib/features/medications/  medication_detail_screen.dart, scan_screen.dart, import_text_screen.dart,
                           review_medications_screen.dart
lib/features/doctor/       patients_screen.dart, patient_detail_screen.dart, reports_screen.dart,
                           doctor_settings_screen.dart
lib/data/                  tcp_glove.dart, wifi_finder.dart, prescription_parser.dart,
                           medication_repository.dart, clinic_repository.dart, demo_clinic.dart
```
Se refac: `core/theme.dart`, `core/widgets.dart`, `core/strings.dart` (toate textele noi stau aici), `app.dart`, `features/live/`, `features/history/`, `features/settings/`, `features/connect/`, `features/onboarding/`, `data/settings_store.dart` și `services/export_service.dart` (raport pe perioadă și pentru mai mulți pacienți).

**Pachete noi.** Versiunile le alege `flutter pub add`, compatibile cu Flutter-ul de acum.

| Pachet | Pentru |
|---|---|
| `google_mlkit_text_recognition` | citirea textului din poză, pe telefon |
| `image_picker` | camera și galeria |
| `timezone`, `flutter_timezone` | notificări la ora locală |
| `material_symbols_icons` | iconițele rotunjite |
| `receive_sharing_intent` | „Trimite către Mănușa” din alte aplicații |
| `flutter_tts` | ghidarea vocală în teste |
| `flutter_launcher_icons`, `flutter_native_splash` (doar la dezvoltare) | iconița și ecranul de pornire |

Mai intră fontul Atkinson Hyperlegible Next în `assets/fonts`. În `AndroidManifest.xml` se adaugă permisiunile pentru notificări programate (`RECEIVE_BOOT_COMPLETED`, `SCHEDULE_EXACT_ALARM`) și primirea de text partajat.

## 6. Etape
Fiecare etapă se încheie cu o aplicație care merge. La final îți dau mesajul de commit, iar commit-ul îl faci tu, pe branch-ul `artur`.

**Etapa 0 · Machetele** (fără cod)
- O pagină cu toate ecranele noi, de pacient și de medic, pe ambele teme, plus paleta și piesele. O poți trimite lui Solo și Alinei.
- *Tu verifici:* culorile, așezarea și textele. Ce nu-ți place se schimbă aici, înainte de cod.

**Etapa 1 · Sistemul de design**
- Paleta nouă în `core/theme.dart`, fontul, iconițele, piesele din `lib/ui/`, iconița aplicației și ecranul de pornire. Ecranele de acum trec pe noul aspect, fără funcții noi. În modul de dezvoltare există un ecran de probă cu toate piesele, pe ambele teme.
- *Tu verifici:* toată aplicația e în noul stil, pe ambele teme, și `flutter test` trece.

**Etapa 2 · Autentificare și roluri**
- Ecranul de pornire, autentificarea, `AuthGate`, cadrul pacientului (4 file) și al medicului (3 file; filele noi arată deocamdată o stare goală), „Ieși din cont”. Prima pornire (avertisment, notificări, mănușă) se mută după autentificare.
- *Tu verifici:* contul de pacient duce în aplicația pacientului, cel de medic în aplicația medicului; o parolă greșită dă un mesaj clar; după repornire rămâi autentificat.

**Etapa 3 · Live nou și Wi-Fi**
- Cardul Mănușa, inelul tremorului, graficul live cu pragul, mâna desenată și graficul degetelor.
- Pentru Wi-Fi: `TcpGlove`, căutarea în rețea, adresa scrisă de mână, setarea rețelei din aplicație, plus firmware-ul cu Wi-Fi și Bluetooth oprit.
- *Tu verifici:* cu cablul USB folosit doar pentru curent, mănușa trimite prin Wi-Fi aceleași valori ca prin USB, 10 minute fără întrerupere. În emulator merge cu adresa scrisă de mână.

**Etapa 4 · Sesiuni cu teste ghidate**
- Alegerea testului, pașii (numărătoare, semnale, ilustrații), tapping-ul cu mănușa și pe ecran, rezultatul cu comparația față de data trecută. Plus baza de date v2 și scenariile simulatorului.
- *Tu verifici:* evaluarea completă merge în Demo. Cu mănușa reală faci 20 de atingeri deget mare–arătător, iar aplicația numără 20 (±1).

**Etapa 5 · Istoricul nou**
- Zi / Săptămână / Lună, săgețile între perioade, procentele, timpul peste prag, calendarul lunii, tapping-ul, perspectivele, raportul PDF al perioadei, datele demo pe 90 de zile.
- *Tu verifici:* pe datele demo, procentele afișate se potrivesc cu un calcul făcut de mână pe CSV.

**Etapa 6 · Remindere și medicamente**
- Fila Remindere (Azi, Medicamentele mele, Alte remindere), adăugarea manuală, stocul, notificările programate cu „Am luat” și „Amână”, avertismentul de stoc mic, reminderul de test.
- *Tu verifici:* un reminder pus peste 2 minute sună și cu telefonul blocat; „Am luat” scade stocul și se poate anula; la stoc mic apare avertismentul.

**Etapa 7 · Scanarea rețetei și importul din notițe**
- Camera sau galeria cu ML Kit, ecranul unde lipești text, „Trimite către Mănușa” din alte aplicații, analizorul, ecranul de verificare.
- *Tu verifici:* o rețetă tipărită și un mesaj din Notițe devin, după verificare, medicamente corecte; un rând citit nesigur apare marcat. În emulator tragi poza în fereastra lui, apoi o alegi din galerie.

**Etapa 8 · Rolul de medic**
- Pacienții, detaliul pacientului (cu graficele din Istoric), Rapoartele (PDF sau CSV, pentru unul sau mai mulți pacienți), Setările medicului, rezumatul săptămânal.
- *Tu verifici:* o sesiune înregistrată ca pacient apare la medic, la Ion Popescu; exportul pentru 2 pacienți produce 2 PDF-uri.

**Etapa 9 · Finisare premium**
- Animații, vibrații la apăsare, ghidare vocală în teste, stări goale, așezare pe două coloane pe tabletă pentru medic, verificarea accesibilității (130 %, TalkBack, contrast), capturi automate ale tuturor ecranelor pe ambele teme.
- *Tu verifici:* lista de accesibilitate și capturile.

## 7. Mai târziu: Supabase sau Firebase
- Recomand **Supabase**. Relația medic–pacient și sumele pe zile se scriu natural în SQL, iar regula „fiecare medic vede doar pacienții lui” stă direct în bază (RLS). Firebase merge și el, dar relațiile și rapoartele sunt mai incomode acolo.
- Se înlocuiesc doar implementările din spatele interfețelor: `AuthRepository`, `ClinicRepository` și sincronizarea sesiunilor, testelor și medicamentelor. Ecranele rămân.
- Atunci apar: crearea contului, „Ai uitat parola?”, legarea pacientului de medic printr-un cod, notificări către medic (push).
- Conectorul Supabase din Claude Code trebuie autorizat înainte, din `/mcp`.

## Riscuri
- **Notificările programate**: Android 14 cere permisiunea „Alarme și mementouri”, iar unele telefoane (Xiaomi, Samsung) opresc aplicațiile în fundal. Aplicația explică pe un ecran ce trebuie permis.
- **Wi-Fi**:
  - consumă mai mult decât Bluetooth, ceea ce contează când apare bateria (Etapa 4 din planul mare); Bluetooth se poate reporni din comutator;
  - mănușa și telefonul trebuie să fie în aceeași rețea;
  - serverul mănușii nu are parolă, deci nu se folosește pe rețele publice;
  - în emulator, căutarea nu primește răspuns (rețeaua emulatorului e izolată), așa că adresa se scrie de mână.
- **Scanarea**: textul tipărit se citește bine, scrisul de mână prost. De aceea ecranul de verificare e obligatoriu.
- **Tapping la 10 pachete pe secundă**: dacă la teste se pierd atingeri la viteză mare, firmware-ul trimite 20 de pachete pe secundă în timpul testului. E o schimbare mică.
- **Parolele scrise în cod** sunt doar pentru demonstrație și dispar cu Supabase. În conturile demo nu se pun date reale de pacienți.
- **Mac cu Intel**: fără `flutter upgrade`. ML Kit mărește aplicația cu câțiva MB.
- **Volumul**: sunt 10 etape. Dacă timpul e scurt, ordinea lor permite oprirea după oricare.

## Verificare
- La fiecare etapă: `flutter analyze` fără probleme, `flutter test` și rulare în emulator. Cele 32 de teste de acum se adaptează la autentificare: `test/screens_render_test.dart` pornește cu un cont salvat.
- Teste noi:
  - autentificarea (corect, greșit, rolul);
  - analizorul de rețete, pe peste 20 de rânduri reale;
  - stocul și zilele rămase;
  - ora următorului reminder;
  - detectorul de tapping, pe semnale generate;
  - sumele pe Zi / Săptămână / Lună și procentele;
  - migrarea bazei de la v1 la v2;
  - desenarea fiecărui ecran nou pe ambele teme și la 130 %.
- Pe mănușa reală: 10 minute prin Wi-Fi fără întreruperi și tapping numărat corect.
- Capturi automate ale tuturor ecranelor, pentru verificarea aspectului (Etapa 9).

## După aprobare
1. Salvez planul în `Aplicatie_Mobile/PLAN_INTERFATA.md`; planul vechi rămâne în `PLAN.md`.
2. Fac machetele (Etapa 0) și ți le trimit.
3. Actualizez ghidul pentru Solo cu trecerea la Wi-Fi.
4. Codul începe după ce validezi machetele, etapă cu etapă.
