#include <Arduino.h>
#include <Wire.h>
#include <math.h>

// Test combinat: IMU MPU-6050 (SDA=21, SCL=22) + 2 senzori flex: DEGET MARE si ARATATOR.
// (Varianta cu doar F1 si F2 conectate; pentru toate 5 degetele vezi combo5.cpp.)
// Fiecare flex are propriul divizor: 3V3 -> flex -> NOD -> 4 x 10k -> GND, cu pinul ESP32 in NOD.
//   F1 = GPIO32 (DegetMare)    F2 = GPIO33 (Aratator)
// Taste de trimis din monitorul serial:
//   o = mana deschisa (flex 0%)    c = pumn strans (flex 100%)    z = recalibreaza giroscopul
#define SDA_PIN 21
#define SCL_PIN 22

const int N_FLEX = 2;
const uint8_t FLEX_PINS[N_FLEX] = {32, 33};
const char *FLEX_NAMES[N_FLEX] = {"DegetMare", "Aratator"};

const float VCC = 3.3;
const float R_FIXED = 40000.0;     // 4 x 10k in serie; puneti valoarea masurata cu multimetrul
const float V_MIN = 0.16;          // sub ~0.15 V ADC-ul ESP32 (11 dB) nu mai masoara corect
const float MIN_SPAN = 2000.0;     // sub 2 kOhm intre "deschis" si "strans" calibrarea nu are sens
const uint32_t PERIOD_US = 10000;  // 100 Hz

// Giroscop +-500 dps (sensibilitate 65.5 LSB/dps): scuturarea voluntara depaseste usor 250 dps
const float GYRO_SENS = 65.5;

uint8_t mpuAddr = 0x68;
float gOff[3] = {0, 0, 0};

// ---- IMU ----
// Cauta MPU-6050 la 0x68 / 0x69 pe pinii dati
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

// ---- Tremor: frecventa estimata din axa cu cea mai multa energie ----
// Pe axa cu semn, o oscilatie de f Hz trece de f ori pe secunda prin zero in sus.
// (Norma |omega| ar da 2f, pentru ca e mereu pozitiva.)
// Fereastra glisanta: frecventa vine din timpul dintre ultimele treceri prin zero, recalculata la fiecare esantion.
const uint32_t WIN_US = 2000000;   // folosim doar trecerile din ultimele 2 s
const uint32_t STALE_US = 700000;  // nicio trecere in 0.7 s = oscilatia s-a oprit
const float HP_ALPHA = 0.05;       // media lenta scoasa din semnal (taie sub ~1 Hz)
const float THR_DPS = 3.0;         // histerezis: ignora zgomotul
const float MIN_RMS_DPS = 2.0;     // sub asta nu consideram ca exista oscilatie
const float MSQ_ALPHA = 0.02;      // RMS glisant, constanta de timp ~0.5 s la 100 Hz
const int MAX_X = 12;              // cate treceri tinem minte pe axa

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

// Frecventa pe axa k din trecerile din ultimele WIN_US; 0 daca sunt prea putine sau s-au oprit
float estimateFreq(int k, uint32_t now) {
  int first = -1, n = 0;
  for (int i = 0; i < xCount[k]; i++) {
    if ((uint32_t)(now - xTime[k][i]) <= WIN_US) {
      if (first < 0) first = i;
      n++;
    }
  }
  if (n < 3) return 0;  // minim 2 perioade complete
  uint32_t last = xTime[k][xCount[k] - 1];
  if ((uint32_t)(now - last) > STALE_US) return 0;
  return (n - 1) * 1e6f / (float)(last - xTime[k][first]);
}

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

void printCal(const char *label, const float r[N_FLEX]) {
  Serial.printf("# %s [kOhm]:", label);
  for (int i = 0; i < N_FLEX; i++) {
    if (isnan(r[i])) Serial.printf(" %s=-", FLEX_NAMES[i]);
    else Serial.printf(" %s=%.1f", FLEX_NAMES[i], r[i] / 1000.0);
  }
  Serial.println();
}

void handleSerial() {
  while (Serial.available()) {
    char c = Serial.read();
    if (c == 'o') {
      for (int i = 0; i < N_FLEX; i++) rOpen[i] = rFilt[i];
      printCal("Mana deschisa", rOpen);
    } else if (c == 'c') {
      for (int i = 0; i < N_FLEX; i++) rClosed[i] = rFilt[i];
      printCal("Pumn strans", rClosed);
    } else if (c == 'z') {
      calibrateGyro();
    }
  }
}

void setup() {
  Serial.begin(115200);
  delay(1000);
  for (int i = 0; i < N_FLEX; i++) {
    analogSetPinAttenuation(FLEX_PINS[i], ADC_11db);
    rFilt[i] = rOpen[i] = rClosed[i] = NAN;
  }

  if (!findMPU(SDA_PIN, SCL_PIN) && !findMPU(22, 23)) {
    Serial.println("# MPU6050 negasit! Verifica firele (SDA=21, SCL=22, VCC=3.3V, GND).");
    while (true) delay(1000);
  }

  writeReg(0x6B, 0x01);  // trezire, ceas de la giroscopul X
  writeReg(0x1A, 0x03);  // filtru digital trece-jos ~44 Hz
  writeReg(0x1B, 0x08);  // gyro +-500 dps
  writeReg(0x1C, 0x00);  // accel +-2g
  delay(100);

  calibrateGyro();
  Serial.println("# Taste: o = mana deschisa, c = pumn strans, z = recalibreaza giroscopul");
  resetTremor();
}

uint32_t nextUs = 0;
uint32_t rateCount = 0, rateT0 = 0;
int rateHz = 0;
uint32_t i2cErr = 0;
uint32_t printCount = 0;
uint32_t lastWarn = 0;

void loop() {
  if (nextUs == 0) {  // prima trecere
    nextUs = micros() + PERIOD_US;
    rateT0 = millis();
  }
  handleSerial();

  uint32_t now = micros();
  if ((int32_t)(now - nextUs) < 0) return;
  nextUs += PERIOD_US;
  if ((int32_t)(now - nextUs) > (int32_t)(5 * PERIOD_US)) nextUs = now + PERIOD_US;  // am ramas mult in urma

  rateCount++;
  if (millis() - rateT0 >= 1000) {
    rateHz = rateCount;
    rateCount = 0;
    rateT0 += 1000;
  }

  // Flex: rezistenta filtrata si procent de indoire pentru fiecare deget
  float pct[N_FLEX];
  char bad[64] = "";
  for (int i = 0; i < N_FLEX; i++) {
    float v = readFlexVolts(FLEX_PINS[i]);
    if (v >= V_MIN && v <= VCC - 0.05) {
      float r = R_FIXED * (VCC - v) / v;
      rFilt[i] = isnan(rFilt[i]) ? r : 0.3 * r + 0.7 * rFilt[i];
    } else {
      rFilt[i] = NAN;
      strcat(bad, FLEX_NAMES[i]);
      strcat(bad, " ");
    }
    pct[i] = -1;  // -1 = necalibrat sau interval prea mic
    if (!isnan(rFilt[i]) && !isnan(rOpen[i]) && !isnan(rClosed[i]) && fabsf(rClosed[i] - rOpen[i]) >= MIN_SPAN) {
      pct[i] = (rFilt[i] - rOpen[i]) / (rClosed[i] - rOpen[i]) * 100.0;
      pct[i] = fmaxf(0, fminf(100, pct[i]));
    }
  }
  if (bad[0] && millis() - lastWarn > 2000) {
    lastWarn = millis();
    Serial.printf("# Flex fara semnal valid (lipsa 3V3, GND sau divizor): %s\n", bad);
  }

  // IMU
  float a[3], g[3];
  if (!readMPU(a, g)) {
    i2cErr++;
    return;
  }
  float accNorm = sqrtf(a[0] * a[0] + a[1] * a[1] + a[2] * a[2]);

  float gc[3];  // giroscop pe axe, fara offset [dps]
  for (int k = 0; k < 3; k++) gc[k] = g[k] - gOff[k];

  float dev[3];
  for (int k = 0; k < 3; k++) {
    float gk = g[k] - gOff[k];
    hp[k] += HP_ALPHA * (gk - hp[k]);
    dev[k] = gk - hp[k];
    msq[k] += MSQ_ALPHA * (dev[k] * dev[k] - msq[k]);
    if (!upState[k] && dev[k] > THR_DPS) {
      upState[k] = true;
      if (xCount[k] == MAX_X) {  // buffer plin: aruncam cea mai veche trecere
        memmove(&xTime[k][0], &xTime[k][1], (MAX_X - 1) * sizeof(uint32_t));
        xCount[k]--;
      }
      xTime[k][xCount[k]++] = now;
    } else if (upState[k] && dev[k] < -THR_DPS) {
      upState[k] = false;
    }
  }
  int best = 0;
  for (int k = 1; k < 3; k++)
    if (msq[k] > msq[best]) best = k;
  rmsEst = sqrtf(msq[best]);
  freqEst = (rmsEst >= MIN_RMS_DPS) ? estimateFreq(best, now) : 0;

  // 10 linii pe secunda: lizibil in monitor si in Teleplot
  if (++printCount % 10 == 0) {
    char line[320];
    int n = 0;
    for (int i = 0; i < N_FLEX; i++)
        n += snprintf(line + n, sizeof(line) - n, "%s_kOhm:%.1f,%s_pct:%.0f,", FLEX_NAMES[i],
                    isnan(rFilt[i]) ? 0.0 : rFilt[i] / 1000.0, FLEX_NAMES[i], pct[i]);
    snprintf(line + n, sizeof(line) - n,
             "Gx:%.1f,Gy:%.1f,Gz:%.1f,Acc_g:%.2f,Freq_Hz:%.1f,Rms_dps:%.1f,Rate_Hz:%d,I2C_err:%lu", gc[0], gc[1],
             gc[2], accNorm, freqEst, rmsEst, rateHz, (unsigned long)i2cErr);
    Serial.println(line);
  }
}
