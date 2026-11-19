/// Toate textele aplicației, într-un singur loc.
abstract final class S {
  static const appTitle = 'Mănușa';

  static const tabLive = 'Live';
  static const tabHistory = 'Istoric';
  static const tabSettings = 'Setări';

  // Live
  static const gloveConnected = 'Mănușă conectată';
  static const gloveConnecting = 'Se conectează…';
  static const gloveDisconnected = 'Mănușă deconectată';
  static const noData = 'Fără date';
  static const simulatedBanner = 'DATE SIMULATE · mod demonstrativ';
  static const powerUsb = 'USB';
  static const batteryLow = 'Baterie descărcată';
  static const tremor = 'Tremor';
  static const noTremor = 'fără tremor';
  static const index = 'indice';
  static const last30s = 'ultimele 30 s';
  static const stateLabel = 'stare:';
  static const fingers = 'Degete';
  static const bendPercent = 'îndoire, %';
  static const fingerNames = ['Mare', 'Arătător', 'Mijlociu', 'Inelar', 'Mic'];
  static const fingersNotCalibrated = 'Degetele nu sunt calibrate.';
  static const calibrateNow = 'Calibrează acum';
  static const startSession = 'Pornește sesiunea';
  static const connectFirst = 'Conectează mănușa ca să pornești o sesiune.';

  // Sesiune
  static const recording = 'Înregistrare';
  static const whatAreYouDoing = 'Ce faci acum?';
  static const activityHints = [
    'Repaus: mâna sprijinită, fără mișcare voită.',
    'Postură: brațul ținut întins, fără sprijin.',
    'Acțiune: o mișcare voită (ex. duci paharul la gură).',
  ];
  static const addNote = 'Adaugă o notă';
  static const addNoteHint = 'de exemplu: am luat medicamentul';
  static const markMoment = 'Marchează un moment';
  static const markMomentHint = 'apare ca reper în istoric';
  static const momentMarked = 'Moment marcat';
  static const noteSaved = 'Notă salvată';
  static const stopSession = 'Oprește sesiunea';
  static const stopConfirmTitle = 'Oprești sesiunea?';
  static const stopConfirmBody = 'Înregistrarea se salvează în Istoric.';
  static const keepRecording = 'Continuă';
  static const save = 'Salvează';
  static const cancel = 'Renunță';
  static const notePlaceholder = 'Scrie nota aici';

  // Istoric
  static const historyTitle = 'Istoric';
  static const day = 'Zi';
  static const week = 'Săptămână';
  static const tremorIndex = 'Indice de tremor';
  static const dayAverage = 'media zilei, din 100';
  static const hourAverage = 'media pe oră, din 100';
  static const sessions = 'Sesiuni';
  static const noSessions = 'Nicio sesiune încă. Pornește una din ecranul Live.';
  static const noSessionsDemo = 'Nicio sesiune simulată încă. Pornește una din Live sau adaugă date demo din Setări.';
  static const threshold = 'prag';

  // Detaliu
  static const session = 'Sesiune';
  static const durationLabel = 'Durată';
  static const avgFrequency = 'Frecvență medie';
  static const avgIndex = 'Indice mediu';
  static const maxIndex = 'Indice maxim';
  static const indexOverTime = 'Indice în timp';
  static const alerts = 'alerte';
  static const note = 'Notă';
  static const sendPdf = 'Trimite raport PDF';
  static const exportCsv = 'Exportă date CSV';
  static const deleteSession = 'Șterge sesiunea';
  static const deleteConfirm = 'Ștergi sesiunea? Nu se mai poate recupera.';
  static const delete = 'Șterge';
  static const simulatedTag = 'SIMULATĂ';

  // Conectare
  static const connectTitle = 'Conectare';
  static const bluetoothOn = 'Bluetooth pornit';
  static const bluetoothOff = 'Bluetooth oprit. Pornește-l din setările telefonului.';
  static const bluetoothUnsupported = 'Acest dispozitiv nu are Bluetooth Low Energy (de exemplu emulatorul). Folosește modul demonstrativ.';
  static const bluetoothNoPermission = 'Aplicația nu are permisiunea de Bluetooth. Dă-i permisiunea din setările telefonului.';
  static const checkingBluetooth = 'Verific Bluetooth-ul…';
  static const searching = 'Caut mănuși în apropiere…';
  static const foundGloves = 'Mănuși găsite';
  static const noGloves = 'Nicio mănușă găsită încă.';
  static const searchAgain = 'Caută din nou';
  static const connect = 'Conectează';
  static const keepClose = 'Ține mănușa pornită, la cel mult 2 metri de telefon.';
  static const demoMode = 'Mod demonstrativ';
  static const demoModeHint = 'Date simulate, fără mănușă';
  static const dataSource = 'Sursa datelor';
  static const dataSourceHints = [
    'Mănușă simulată, fără hardware.',
    'Mănușa legată prin USB la calculator; datele vin prin puntea de pe calculator.',
    'Mănușa reală, fără fir.',
  ];
  static const usbTitle = 'Mănușa prin USB';
  static const usbSteps = [
    'Leagă mănușa prin cablul USB la calculator.',
    'Închide monitorul serial, dacă e deschis.',
    'Pe calculator, în folderul Manusa, pornește puntea:',
  ];
  static const usbCommand = '~/.platformio/penv/bin/python tools/usb_bridge.py';
  static const usbWaiting = 'Aștept puntea de pe calculator…';
  static const usbConnected = 'Primesc date de la mănușă prin USB.';
  static const continueLabel = 'Continuă';

  // Calibrare
  static const calibrationTitle = 'Calibrare';
  static const calibrationSteps = ['Mână deschisă', 'Pumn strâns', 'Mână nemișcată, 2 secunde'];
  static const calibrationInstructions = [
    'Ține mâna deschisă, cu degetele întinse.',
    'Strânge pumnul cât poți de tare.',
    'Sprijină mâna și nu o mișca 2 secunde.',
  ];
  static const calibrationButtons = ['Salvează „mână deschisă”', 'Salvează „pumn”', 'Calibrează giroscopul'];
  static const holdPosition = 'Ține poziția până apare confirmarea.';
  static const saving = 'Se salvează…';
  static const calibrationDone = 'Calibrare gata';
  static const calibrationFailed = 'Mănușa nu a confirmat. Verifică conexiunea și încearcă din nou.';
  static const calibrationDoneBody = 'Degetele și giroscopul sunt calibrate.';
  static const done = 'Gata';

  // Setări
  static const settingsTitle = 'Setări';
  static const gloveSection = 'Mănușă';
  static const alertsSection = 'Alerte';
  static const appSection = 'Aplicație';
  static const calibration = 'Calibrare';
  static const lastCalibration = 'ultima:';
  static const neverCalibrated = 'nefăcută încă';
  static const alertThreshold = 'Prag alertă';
  static const alertThresholdHint = 'indice, din 100';
  static const vibrateOnAlert = 'Vibrație la alertă';
  static const testVibration = 'Test vibrație';
  static const vibrationSent = 'Comanda de vibrație a fost trimisă mănușii.';
  static const vibrationSimulated = 'Mănușa simulată nu are motor: comanda a fost doar înregistrată.';
  static const addDemoData = 'Adaugă o săptămână de date demo';
  static const demoDataAdded = 'Am adăugat sesiuni demo în Istoric.';
  static const theme = 'Temă';
  static const themeSystem = 'Automată';
  static const themeLight = 'Deschisă';
  static const themeDark = 'Întunecată';
  static const instructions = 'Instrucțiuni';
  static const about = 'Despre';
  static const notMedicalDevice = 'Nu este dispozitiv medical';
  static const decrease = 'Scade pragul';
  static const increase = 'Crește pragul';

  // Alerte
  static const alertTitle = 'Tremor peste prag';

  // Prima pornire și Despre
  static const welcomeTitle = 'Bun venit';
  static const welcomeBody =
      'Mănușa măsoară tremorul mâinii și îndoirea degetelor. Aplicația îți arată datele în timp real, le păstrează în Istoric și poate pregăti un raport pentru medic.';
  static const disclaimerTitle = 'Important';
  static const disclaimerBody =
      'Aplicația nu este un dispozitiv medical și nu pune diagnostice. Valorile sunt orientative. Pentru orice decizie despre tratament, vorbește cu medicul tău.';
  static const dataStaysLocal = 'Datele rămân pe telefon. Pleacă de aici doar când trimiți tu un raport.';
  static const understood = 'Am înțeles';
  static const haveGlove = 'Am mănușa';
  static const tryDemo = 'Încerc cu date simulate';
  static const aboutVersion = 'Versiunea 0.1 · proiect Artur și Solo';
  static const pdfFooter = 'Generat de aplicația Mănușa. Nu este dispozitiv medical; valorile sunt orientative.';
}
