// Bluetooth e oprit implicit (decizia din 21 nov 2026: Wi-Fi în loc de Bluetooth).
// Se repornește cu build_flags = -DGLOVE_BLE=1 în platformio.ini, mediul [env:glove].
#ifndef GLOVE_BLE
#define GLOVE_BLE 0
#endif

#include <Arduino.h>
#include <Preferences.h>
#include <WiFi.h>
#include <WiFiUdp.h>
#include <Wire.h>
#include <math.h>
#if GLOVE_BLE
#include <NimBLEDevice.h>
#endif

// Firmware-ul mănușii: citește IMU-ul și senzorii flex și trimite pachetul Live din contractul v1
// (14 octeți, 10 pe secundă) pe mai multe căi deodată:
//   - USB: linii „P <28 cifre hex>”, citite de tools/usb_bridge.py pe calculator;
//   - Wi-Fi: aceleași linii, pe un server TCP la portul 8765 (aplicația se leagă direct de mănușă);
//     mănușa răspunde la căutare pe UDP 8766 („MANUSA?” → „MANUSA <nume> <ip>”);
//   - Bluetooth (doar cu GLOVE_BLE=1): caracteristica Live (notify).
// Comenzile vin pe aceleași căi: „C <cod> <valoare>” (USB și Wi-Fi), caracteristica Control [cod, valoare].
// Rețeaua Wi-Fi se setează pe USB sau din aplicație: „W <rețea>;<parolă>” (rămâne salvată în mănușă).
// Pentru monitorul serial merg și tastele o / c / z (mână deschisă / pumn / giroscop).
//
// Montaj (ca în combo2.cpp): IMU SDA=21, SCL=22; F1 deget mare = GPIO32, F2 arătător = GPIO33.
// F3–F5 (GPIO 34–36) sunt citiți, dar apar ca „necalibrați” (255) până sunt legați și calibrați.
#define SDA_PIN 21
#define SCL_PIN 22
#define LED_PIN 2  // LED-ul plăcii clipește la comanda „vibrează”, până există motorul

// ---- Contractul (identic cu Aplicatie_Mobile/lib/core/contract.dart) ----
#define SERVICE_UUID "4d414e55-0001-4a5f-9c1d-0a1b2c3d4e5f"
#define LIVE_UUID "4d414e55-0002-4a5f-9c1d-0a1b2c3d4e5f"
#define CONTROL_UUID "4d414e55-0003-4a5f-9c1d-0a1b2c3d4e5f"
const uint8_t CONTRACT_VERSION = 1;
const uint8_t FINGER_NOT_CALIBRATED = 255;
const uint8_t BATTERY_USB = 255;
enum Command : uint8_t { CAL_OPEN = 1, CAL_FIST = 2, CAL_GYRO = 3, SESSION_START = 4, SESSION_STOP = 5, THRESHOLD = 6, VIBRATE = 7 };
const uint8_t FLAG_FLEX_CAL = 1 << 0, FLAG_GYRO_CAL = 1 << 1, FLAG_SESSION = 1 << 2;

const int N_FLEX = 5;
const uint8_t FLEX_PINS[N_FLEX] = {32, 33, 34, 35, 36};

const float VCC = 3.3;
const float R_FIXED = 40000.0;     // 4 x 10k in serie; puneti valoarea masurata cu multimetrul
const float V_MIN = 0.16;          // sub ~0.15 V ADC-ul ESP32 (11 dB) nu mai masoara corect
const float MIN_SPAN = 2000.0;     // sub 2 kOhm intre "deschis" si "strans" calibrarea nu are sens
const float R_PLAUSIBLE_MIN = 5000.0;    // un flex real are zeci de kOhm; un pin nelegat dă valori aberante
const float R_PLAUSIBLE_MAX = 250000.0;
const uint32_t PERIOD_US = 10000;  // 100 Hz
const float GYRO_SENS = 65.5;      // ±500 °/s

// Indicele de tremor 0–100: RMS-ul giroscopului raportat la 30 °/s (același ca în simulatorul aplicației).
const float INDEX_FULL_SCALE_DPS = 30.0;

uint8_t mpuAddr = 0x68;
float gOff[3] = {0, 0, 0};
Preferences prefs;

// ---- IMU ----
bool findMPU(int sda, int scl) {
  Wire.end();
  Wire.begin(sda, scl);
  Wire.setClock(400000);
  delay(20);
  const uint8_t addrs[2] = {0x68, 0x69};
  for (uint8_t a : addrs) {
    Wire.beginTransmission(a);
    if (Wire.endTransmission() == 0) {
      mpuAddr = a;
      Serial.printf("# MPU6050 gasit la 0x%02X (SDA=%d, SCL=%d)\n", a, sda, scl);
      return true;
    }
  }
  return false;
}

void writeReg(uint8_t reg, uint8_t val) {
  Wire.beginTransmission(mpuAddr);
  Wire.write(reg);
  Wire.write(val);
  Wire.endTransmission();
}

bool readRegs(uint8_t reg, uint8_t *buf, uint8_t len) {
  Wire.beginTransmission(mpuAddr);
  Wire.write(reg);
  if (Wire.endTransmission(false) != 0) return false;
  if (Wire.requestFrom(mpuAddr, len) != len) return false;
  for (uint8_t i = 0; i < len; i++) buf[i] = Wire.read();
  return true;
}

// a in g, g in grade/secunda (fara offset)
bool readMPU(float a[3], float g[3]) {
  uint8_t d[14];
  if (!readRegs(0x3B, d, 14)) return false;
  a[0] = (int16_t)((d[0] << 8) | d[1]) / 16384.0;
  a[1] = (int16_t)((d[2] << 8) | d[3]) / 16384.0;
  a[2] = (int16_t)((d[4] << 8) | d[5]) / 16384.0;
  g[0] = (int16_t)((d[8] << 8) | d[9]) / GYRO_SENS;
  g[1] = (int16_t)((d[10] << 8) | d[11]) / GYRO_SENS;
  g[2] = (int16_t)((d[12] << 8) | d[13]) / GYRO_SENS;
  return true;
}

// ---- Tremor (estimatorul din combo2.cpp) ----
const uint32_t WIN_US = 2000000;
const uint32_t STALE_US = 700000;
const float HP_ALPHA = 0.05;
const float THR_DPS = 3.0;
const float MIN_RMS_DPS = 2.0;
const float MSQ_ALPHA = 0.02;
const int MAX_X = 12;

float hp[3] = {0, 0, 0};
bool upState[3] = {false, false, false};
float msq[3] = {0, 0, 0};
uint32_t xTime[3][MAX_X];
int xCount[3] = {0, 0, 0};
float freqEst = 0, rmsEst = 0;

void resetTremor() {
  for (int k = 0; k < 3; k++) {
    hp[k] = 0;
    upState[k] = false;
    msq[k] = 0;
    xCount[k] = 0;
  }
  freqEst = 0;
  rmsEst = 0;
}

float estimateFreq(int k, uint32_t now) {
  int first = -1, n = 0;
  for (int i = 0; i < xCount[k]; i++) {
    if ((uint32_t)(now - xTime[k][i]) <= WIN_US) {
      if (first < 0) first = i;
      n++;
    }
  }
  if (n < 3) return 0;
  uint32_t last = xTime[k][xCount[k] - 1];
  if ((uint32_t)(now - last) > STALE_US) return 0;
  return (n - 1) * 1e6f / (float)(last - xTime[k][first]);
}

bool gyroCalibrated = false;

void calibrateGyro() {
  Serial.println("# Calibrare giroscop: tine mana NEMISCATA 2 secunde...");
  float s[3] = {0, 0, 0};
  int ok = 0;
  for (int i = 0; i < 400; i++) {
    float a[3], g[3];
    if (readMPU(a, g)) {
      for (int k = 0; k < 3; k++) s[k] += g[k];
      ok++;
    }
    delay(5);
  }
  if (ok == 0) {
    Serial.println("# Calibrare esuata: IMU-ul nu raspunde");
    return;
  }
  for (int k = 0; k < 3; k++) gOff[k] = s[k] / ok;
  gyroCalibrated = true;
  Serial.printf("# Offset gyro [dps]: %.2f %.2f %.2f\n", gOff[0], gOff[1], gOff[2]);
  resetTremor();
}

// ---- Flex ----
float readFlexVolts(uint8_t pin) {
  uint32_t s = 0;
  for (int i = 0; i < 8; i++) s += analogReadMilliVolts(pin);
  return s / 8000.0;
}

float rFilt[N_FLEX], rOpen[N_FLEX], rClosed[N_FLEX];

bool plausible(float r) { return !isnan(r) && r >= R_PLAUSIBLE_MIN && r <= R_PLAUSIBLE_MAX; }

/// Un deget e calibrat dacă are ambele capete plauzibile și suficient de departe unul de altul.
bool fingerCalibrated(int i) { return plausible(rOpen[i]) && plausible(rClosed[i]) && fabsf(rClosed[i] - rOpen[i]) >= MIN_SPAN; }

bool anyFingerCalibrated() {
  for (int i = 0; i < N_FLEX; i++)
    if (fingerCalibrated(i)) return true;
  return false;
}

void saveCalibration() {
  prefs.begin("manusa", false);
  prefs.putBytes("rOpen", rOpen, sizeof(rOpen));
  prefs.putBytes("rClosed", rClosed, sizeof(rClosed));
  prefs.end();
}

void loadCalibration() {
  prefs.begin("manusa", true);
  if (prefs.getBytesLength("rOpen") == sizeof(rOpen)) prefs.getBytes("rOpen", rOpen, sizeof(rOpen));
  if (prefs.getBytesLength("rClosed") == sizeof(rClosed)) prefs.getBytes("rClosed", rClosed, sizeof(rClosed));
  prefs.end();
}

void printCal(const char *label, const float r[N_FLEX]) {
  Serial.printf("# %s [kOhm]:", label);
  for (int i = 0; i < N_FLEX; i++) {
    if (isnan(r[i])) Serial.printf(" F%d=-", i + 1);
    else Serial.printf(" F%d=%.1f", i + 1, r[i] / 1000.0);
  }
  Serial.println();
}

// ---- Comenzi (de pe USB sau Bluetooth) ----
bool sessionActive = false;
uint8_t alertThreshold = 60;
uint32_t ledOffAt = 0;

void runCommand(uint8_t code, uint8_t value) {
  switch (code) {
    case CAL_OPEN:
      for (int i = 0; i < N_FLEX; i++) rOpen[i] = rFilt[i];
      printCal("Mana deschisa", rOpen);
      saveCalibration();
      break;
    case CAL_FIST:
      for (int i = 0; i < N_FLEX; i++) rClosed[i] = rFilt[i];
      printCal("Pumn strans", rClosed);
      saveCalibration();
      break;
    case CAL_GYRO:
      calibrateGyro();
      break;
    case SESSION_START:
      sessionActive = true;
      break;
    case SESSION_STOP:
      sessionActive = false;
      break;
    case THRESHOLD:
      alertThreshold = value;
      break;
    case VIBRATE:
      // Fără motor încă: LED-ul plăcii se aprinde (300 ms alertă, 100 ms confirmare).
      digitalWrite(LED_PIN, HIGH);
      ledOffAt = millis() + (value == 1 ? 300 : 100);
      break;
  }
  Serial.printf("# Comanda %u (%u) executata\n", code, value);
}

// Comanda primită prin Bluetooth se execută în bucla principală, nu în firul Bluetooth.
volatile bool blePending = false;
volatile uint8_t bleCode = 0, bleValue = 0;

// ---- Wi-Fi ----
char gloveName[16];
WiFiServer tcpServer(8765);
WiFiClient tcpClient;
WiFiUDP udp;
bool wifiStarted = false;
bool wifiAnnounced = false;

void startWifi() {
  prefs.begin("wifi", true);
  String ssid = prefs.getString("ssid", "");
  String pass = prefs.getString("pass", "");
  prefs.end();
  if (ssid.length() == 0) {
    Serial.println("# Wi-Fi: nicio retea salvata. Trimite: W <retea>;<parola>");
    return;
  }
  WiFi.mode(WIFI_STA);
  WiFi.setHostname(gloveName);
  WiFi.begin(ssid.c_str(), pass.c_str());
  wifiStarted = true;
  wifiAnnounced = false;
  Serial.printf("# Wi-Fi: ma conectez la %s\n", ssid.c_str());
}

// „W <rețea>;<parolă>”: salvează rețeaua și se reconectează.
void saveWifi(const char *arg) {
  const char *sep = strchr(arg, ';');
  if (!sep) {
    Serial.println("# Wi-Fi: format gresit. Scrie: W <retea>;<parola>");
    return;
  }
  String ssid = String(arg).substring(0, sep - arg);
  ssid.trim();
  String pass = String(sep + 1);
  prefs.begin("wifi", false);
  prefs.putString("ssid", ssid);
  prefs.putString("pass", pass);
  prefs.end();
  Serial.printf("# Wi-Fi: retea salvata (%s)\n", ssid.c_str());
  WiFi.disconnect(true);
  delay(100);
  startWifi();
}

void handleLine(char *line) {
  unsigned code = 0, value = 0;
  if (line[0] == 'C' && sscanf(line + 1, "%u %u", &code, &value) >= 1) runCommand(code, value);
  if (line[0] == 'W' && line[1] == ' ') saveWifi(line + 2);
}

char tcpBuf[96];
int tcpLen = 0;

void loopWifi() {
  if (!wifiStarted) return;
  if (WiFi.status() != WL_CONNECTED) {
    wifiAnnounced = false;
    return;
  }
  if (!wifiAnnounced) {
    tcpServer.begin();
    tcpServer.setNoDelay(true);
    udp.begin(8766);
    Serial.printf("# Wi-Fi conectat: %s, portul 8765 (%s)\n", WiFi.localIP().toString().c_str(), gloveName);
    wifiAnnounced = true;
  }
  // O singură aplicație odată; una nouă o înlocuiește pe cea veche.
  WiFiClient incoming = tcpServer.available();
  if (incoming) {
    if (tcpClient) tcpClient.stop();
    tcpClient = incoming;
    tcpClient.setNoDelay(true);
    tcpLen = 0;
    Serial.println("# Wi-Fi: aplicatia s-a conectat");
  }
  while (tcpClient && tcpClient.connected() && tcpClient.available()) {
    char c = tcpClient.read();
    if (c == '\r') continue;
    if (c == '\n') {
      tcpBuf[tcpLen] = 0;
      handleLine(tcpBuf);
      tcpLen = 0;
      continue;
    }
    if (tcpLen < (int)sizeof(tcpBuf) - 1) tcpBuf[tcpLen++] = c;
  }
  // Căutarea din aplicație: răspunde cu numele și adresa.
  if (udp.parsePacket() > 0) {
    char q[16];
    int n = udp.read(q, sizeof(q) - 1);
    q[n > 0 ? n : 0] = 0;
    if (strncmp(q, "MANUSA?", 7) == 0) {
      udp.beginPacket(udp.remoteIP(), udp.remotePort());
      udp.printf("MANUSA %s %s", gloveName, WiFi.localIP().toString().c_str());
      udp.endPacket();
    }
  }
}

char lineBuf[96];
int lineLen = 0;

void handleSerial() {
  while (Serial.available()) {
    char c = Serial.read();
    // Tastele simple din monitorul serial (fără Enter).
    if (lineLen == 0 && (c == 'o' || c == 'c' || c == 'z')) {
      runCommand(c == 'o' ? CAL_OPEN : (c == 'c' ? CAL_FIST : CAL_GYRO), 0);
      continue;
    }
    if (c == '\r') continue;
    if (c == '\n') {
      lineBuf[lineLen] = 0;
      handleLine(lineBuf);
      lineLen = 0;
      continue;
    }
    if (lineLen < (int)sizeof(lineBuf) - 1) lineBuf[lineLen++] = c;
  }
}

// ---- Bluetooth (doar cu GLOVE_BLE=1) ----
#if GLOVE_BLE
NimBLECharacteristic *liveChr = nullptr;
bool bleConnected = false;

class ServerCallbacks : public NimBLEServerCallbacks {
  void onConnect(NimBLEServer *server, NimBLEConnInfo &info) override {
    bleConnected = true;
    Serial.println("# Bluetooth: telefon conectat");
  }
  void onDisconnect(NimBLEServer *server, NimBLEConnInfo &info, int reason) override {
    bleConnected = false;
    Serial.println("# Bluetooth: telefon deconectat");
    NimBLEDevice::startAdvertising();
  }
};

class ControlCallbacks : public NimBLECharacteristicCallbacks {
  void onWrite(NimBLECharacteristic *chr, NimBLEConnInfo &info) override {
    NimBLEAttValue v = chr->getValue();
    if (v.length() < 1) return;
    bleCode = v.data()[0];
    bleValue = v.length() > 1 ? v.data()[1] : 0;
    blePending = true;
  }
};

void setupBle() {
  const char *name = gloveName;
  NimBLEDevice::init(name);
  NimBLEServer *server = NimBLEDevice::createServer();
  server->setCallbacks(new ServerCallbacks());
  NimBLEService *service = server->createService(SERVICE_UUID);
  liveChr = service->createCharacteristic(LIVE_UUID, NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::NOTIFY);
  NimBLECharacteristic *control = service->createCharacteristic(CONTROL_UUID, NIMBLE_PROPERTY::WRITE);
  control->setCallbacks(new ControlCallbacks());
  service->start();
  NimBLEAdvertising *adv = NimBLEDevice::getAdvertising();
  adv->setName(name);
  adv->addServiceUUID(SERVICE_UUID);
  adv->enableScanResponse(true);
  adv->start();
  Serial.printf("# Bluetooth: se anunta ca %s\n", name);
}
#endif

// ---- Pachetul Live ----
void buildPacket(uint8_t out[14], const uint8_t fingers[N_FLEX], uint8_t index) {
  uint16_t freq = (uint16_t)lroundf(fminf(freqEst, 655.0f) * 100);
  uint16_t rms = (uint16_t)lroundf(fminf(rmsEst, 655.0f) * 100);
  out[0] = CONTRACT_VERSION;
  for (int i = 0; i < N_FLEX; i++) out[1 + i] = fingers[i];
  out[6] = freq & 0xFF;
  out[7] = freq >> 8;
  out[8] = rms & 0xFF;
  out[9] = rms >> 8;
  out[10] = index;
  out[11] = 0;  // stare: repaus (detecția posturii/acțiunii vine mai târziu)
  out[12] = BATTERY_USB;
  out[13] = (anyFingerCalibrated() ? FLAG_FLEX_CAL : 0) | (gyroCalibrated ? FLAG_GYRO_CAL : 0) | (sessionActive ? FLAG_SESSION : 0);
}

void setup() {
  Serial.begin(115200);
  delay(1000);
  pinMode(LED_PIN, OUTPUT);
  for (int i = 0; i < N_FLEX; i++) {
    analogSetPinAttenuation(FLEX_PINS[i], ADC_11db);
    rFilt[i] = rOpen[i] = rClosed[i] = NAN;
  }
  loadCalibration();
  printCal("Calibrare incarcata, deschis", rOpen);
  printCal("Calibrare incarcata, strans", rClosed);

  if (!findMPU(SDA_PIN, SCL_PIN) && !findMPU(22, 23)) {
    Serial.println("# MPU6050 negasit! Verifica firele (SDA=21, SCL=22, VCC=3.3V, GND).");
    while (true) delay(1000);
  }
  writeReg(0x6B, 0x01);  // trezire, ceas de la giroscopul X
  writeReg(0x1A, 0x03);  // filtru digital trece-jos ~44 Hz
  writeReg(0x1B, 0x08);  // gyro ±500 dps
  writeReg(0x1C, 0x00);  // accel ±2g
  delay(100);

  calibrateGyro();
  uint64_t mac = ESP.getEfuseMac();
  snprintf(gloveName, sizeof(gloveName), "Manusa-%02X%02X", (uint8_t)(mac >> 32), (uint8_t)(mac >> 40));
#if GLOVE_BLE
  setupBle();
#endif
  startWifi();
  Serial.println("# Gata. Pachetele Live: linii \"P <hex>\". Taste: o = mana deschisa, c = pumn, z = giroscop");
}

uint32_t nextUs = 0;
uint32_t tick = 0;

void loop() {
  if (nextUs == 0) nextUs = micros() + PERIOD_US;
  handleSerial();
  loopWifi();
#if GLOVE_BLE
  if (blePending) {
    blePending = false;
    runCommand(bleCode, bleValue);
  }
#endif
  if (ledOffAt && millis() > ledOffAt) {
    digitalWrite(LED_PIN, LOW);
    ledOffAt = 0;
  }

  uint32_t now = micros();
  if ((int32_t)(now - nextUs) < 0) return;
  nextUs += PERIOD_US;
  if ((int32_t)(now - nextUs) > (int32_t)(5 * PERIOD_US)) nextUs = now + PERIOD_US;

  // Flex
  uint8_t fingers[N_FLEX];
  for (int i = 0; i < N_FLEX; i++) {
    float v = readFlexVolts(FLEX_PINS[i]);
    if (v >= V_MIN && v <= VCC - 0.05) {
      float r = R_FIXED * (VCC - v) / v;
      rFilt[i] = isnan(rFilt[i]) ? r : 0.3 * r + 0.7 * rFilt[i];
    } else {
      rFilt[i] = NAN;
    }
    fingers[i] = FINGER_NOT_CALIBRATED;
    if (fingerCalibrated(i) && !isnan(rFilt[i])) {
      float pct = (rFilt[i] - rOpen[i]) / (rClosed[i] - rOpen[i]) * 100.0;
      fingers[i] = (uint8_t)lroundf(fmaxf(0, fminf(100, pct)));
    }
  }

  // IMU și tremor
  float a[3], g[3];
  if (!readMPU(a, g)) return;
  for (int k = 0; k < 3; k++) {
    float gk = g[k] - gOff[k];
    hp[k] += HP_ALPHA * (gk - hp[k]);
    float dev = gk - hp[k];
    msq[k] += MSQ_ALPHA * (dev * dev - msq[k]);
    if (!upState[k] && dev > THR_DPS) {
      upState[k] = true;
      if (xCount[k] == MAX_X) {
        memmove(&xTime[k][0], &xTime[k][1], (MAX_X - 1) * sizeof(uint32_t));
        xCount[k]--;
      }
      xTime[k][xCount[k]++] = now;
    } else if (upState[k] && dev < -THR_DPS) {
      upState[k] = false;
    }
  }
  int best = 0;
  for (int k = 1; k < 3; k++)
    if (msq[k] > msq[best]) best = k;
  rmsEst = sqrtf(msq[best]);
  freqEst = (rmsEst >= MIN_RMS_DPS) ? estimateFreq(best, now) : 0;

  // Pachetul Live, de 10 ori pe secundă.
  if (++tick % 10 != 0) return;
  uint8_t index = (uint8_t)lroundf(fminf(100, rmsEst * 100 / INDEX_FULL_SCALE_DPS));
  uint8_t packet[14];
  buildPacket(packet, fingers, index);
  char hex[2 * 14 + 1];
  for (int i = 0; i < 14; i++) sprintf(hex + 2 * i, "%02x", packet[i]);
  Serial.printf("P %s\n", hex);
  if (tcpClient && tcpClient.connected()) tcpClient.printf("P %s\n", hex);
#if GLOVE_BLE
  if (bleConnected && liveChr) {
    liveChr->setValue(packet, sizeof(packet));
    liveChr->notify();
  }
#endif
}
