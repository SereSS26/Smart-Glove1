#include <Arduino.h>
#include <Wire.h>
#include <math.h>

// Test combinat: IMU MPU-6050 (SDA=21, SCL=22) + senzor flex pe degetul mare (GPIO32).
// Nu are nevoie de buton sau de motor. Taste de trimis din monitorul serial:
//   o = mana deschisa (flex 0%)    c = pumn strans (flex 100%)    z = recalibreaza giroscopul
#define SDA_PIN 21
#define SCL_PIN 22
#define FLEX_PIN 32

const float VCC = 3.3;
const float R_FIXED = 40000.0;     // 4 x 10k in serie; puneti valoarea masurata cu multimetrul
const float V_MIN = 0.16;          // sub ~0.15 V ADC-ul ESP32 (11 dB) nu mai masoara corect
const uint32_t PERIOD_US = 10000;  // 100 Hz

// Giroscop +-500 dps (sensibilitate 65.5 LSB/dps): scuturarea voluntara depaseste usor 250 dps
const float GYRO_SENS = 65.5;

uint8_t mpuAddr = 0x68;
float gOff[3] = {0, 0, 0};

// ---- IMU ----
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
const uint32_t WIN_MS = 4000;
const float HP_ALPHA = 0.05;    // media lenta scoasa din semnal (taie sub ~1 Hz)
const float THR_DPS = 3.0;      // histerezis: ignora zgomotul
const float MIN_RMS_DPS = 2.0;  // sub asta nu consideram ca exista oscilatie

float hp[3] = {0, 0, 0};
bool upState[3] = {false, false, false};
int crossings[3] = {0, 0, 0};
float energy[3] = {0, 0, 0};
int winSamples = 0;
uint32_t winStart = 0;
float freqEst = 0, rmsEst = 0;

void resetTremor() {
  for (int k = 0; k < 3; k++) {
    hp[k] = 0;
    upState[k] = false;
    crossings[k] = 0;
    energy[k] = 0;
  }
  winSamples = 0;
  winStart = millis();
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
float readFlexVolts() {
  uint32_t s = 0;
  for (int i = 0; i < 8; i++) s += analogReadMilliVolts(FLEX_PIN);
  return s / 8000.0;
}

float rFilt = NAN, rOpen = NAN, rClosed = NAN;

void handleSerial() {
  while (Serial.available()) {
    char c = Serial.read();
    if (c == 'o' && !isnan(rFilt)) {
      rOpen = rFilt;
      Serial.printf("# Mana deschisa = %.1f kOhm\n", rOpen / 1000.0);
    } else if (c == 'c' && !isnan(rFilt)) {
      rClosed = rFilt;
      Serial.printf("# Pumn strans = %.1f kOhm\n", rClosed / 1000.0);
    } else if (c == 'z') {
      calibrateGyro();
    }
  }
}

void setup() {
  Serial.begin(115200);
  delay(1000);
  analogSetPinAttenuation(FLEX_PIN, ADC_11db);

  Wire.begin(SDA_PIN, SCL_PIN);
  Wire.setClock(400000);
  Wire.beginTransmission(mpuAddr);
  if (Wire.endTransmission() != 0) {
    mpuAddr = 0x69;
    Wire.beginTransmission(mpuAddr);
    if (Wire.endTransmission() != 0) {
      Serial.println("# MPU6050 negasit! Verifica firele (SDA=21, SCL=22, VCC=3.3V, GND).");
      while (true) delay(1000);
    }
  }
  Serial.printf("# MPU6050 gasit la 0x%02X\n", mpuAddr);

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

  // Flex
  float v = readFlexVolts();
  bool flexOk = (v >= V_MIN && v <= VCC - 0.05);
  if (flexOk) {
    float r = R_FIXED * (VCC - v) / v;
    rFilt = isnan(rFilt) ? r : 0.3 * r + 0.7 * rFilt;
  } else {
    rFilt = NAN;
    if (millis() - lastWarn > 2000) {
      lastWarn = millis();
      Serial.printf("# Flex: V=%.2f, verifica legaturile (3.3V -> flex -> D32 -> rezistenta -> GND)\n", v);
    }
  }
  float pct = -1;  // -1 = necalibrat
  if (!isnan(rFilt) && !isnan(rOpen) && !isnan(rClosed) && rClosed != rOpen) {
    pct = (rFilt - rOpen) / (rClosed - rOpen) * 100.0;
    pct = fmaxf(0, fminf(100, pct));
  }

  // IMU
  float a[3], g[3];
  if (!readMPU(a, g)) {
    i2cErr++;
    return;
  }
  float accNorm = sqrtf(a[0] * a[0] + a[1] * a[1] + a[2] * a[2]);

  float dev[3];
  float devNorm2 = 0;
  for (int k = 0; k < 3; k++) {
    float gk = g[k] - gOff[k];
    hp[k] += HP_ALPHA * (gk - hp[k]);
    dev[k] = gk - hp[k];
    devNorm2 += dev[k] * dev[k];
    energy[k] += dev[k] * dev[k];
    if (!upState[k] && dev[k] > THR_DPS) {
      upState[k] = true;
      crossings[k]++;
    } else if (upState[k] && dev[k] < -THR_DPS) {
      upState[k] = false;
    }
  }
  winSamples++;
  if (millis() - winStart >= WIN_MS) {
    int best = 0;
    for (int k = 1; k < 3; k++)
      if (energy[k] > energy[best]) best = k;
    rmsEst = sqrtf(energy[best] / (winSamples > 0 ? winSamples : 1));
    freqEst = (rmsEst >= MIN_RMS_DPS) ? crossings[best] * 1000.0 / WIN_MS : 0;
    resetTremor();
  }

  // 10 linii pe secunda: lizibil in monitor si in Teleplot
  if (++printCount % 10 == 0) {
    Serial.printf("Flex_kOhm:%.1f,Flex_pct:%.0f,Gyro_dps:%.1f,Acc_g:%.2f,Freq_Hz:%.1f,Rms_dps:%.1f,Rate_Hz:%d,I2C_err:%lu\n",
                  isnan(rFilt) ? 0.0 : rFilt / 1000.0, pct, sqrtf(devNorm2), accNorm, freqEst, rmsEst, rateHz,
                  (unsigned long)i2cErr);
  }
}
