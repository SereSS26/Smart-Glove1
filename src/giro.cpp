#include <Arduino.h>
#include <Wire.h>
#include <math.h>

// Test giroscop + accelerometru MPU-6050.
// Cauta singur senzorul pe SDA=21/SCL=22 (ca in combo2/combo5), apoi pe SDA=22/SCL=23.
// Afiseaza de 5 ori pe secunda:
//   Gx, Gy, Gz  = viteza de rotatie pe fiecare axa [grade/s]; in repaus trebuie sa fie ~0
//   Ax, Ay, Az  = acceleratia [g]; in repaus, pe axa care e in sus trebuie sa fie ~1
//   Roll, Pitch = inclinarea mainii [grade] (filtru complementar giroscop + accelerometru)
//   Yaw         = rotatia in plan orizontal [grade]; deriveaza incet, e normal (nu exista magnetometru)
// Taste din monitorul serial:
//   z = recalibreaza (mana nemiscata)    r = pune Roll/Pitch/Yaw pe 0

const float GYRO_SENS = 65.5;  // +-500 dps
const float ALPHA = 0.98;      // filtru complementar

uint8_t mpuAddr = 0x68;
float gOff[3] = {0, 0, 0};
float roll = 0, pitch = 0, yaw = 0;
uint32_t lastUs = 0;
uint32_t i2cErr = 0;

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

bool readMPU(float a[3], float g[3]) {
  uint8_t d[14];
  if (!readRegs(0x3B, d, 14)) return false;
  for (int k = 0; k < 3; k++) {
    a[k] = (int16_t)((d[2 * k] << 8) | d[2 * k + 1]) / 16384.0;
    g[k] = (int16_t)((d[8 + 2 * k] << 8) | d[9 + 2 * k]) / GYRO_SENS;
  }
  return true;
}

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

void calibrate() {
  Serial.println("# Calibrare: tine mana NEMISCATA 2 secunde...");
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
  Serial.printf("# Offset giroscop [dps]: X=%.2f Y=%.2f Z=%.2f\n", gOff[0], gOff[1], gOff[2]);
  if (fabsf(gOff[0]) > 20 || fabsf(gOff[1]) > 20 || fabsf(gOff[2]) > 20)
    Serial.println("# ATENTIE: offset foarte mare - ai miscat mana sau senzorul e defect");

  // Porneste Roll/Pitch din accelerometru
  float a[3], g[3];
  if (readMPU(a, g)) {
    roll = atan2f(a[1], a[2]) * RAD_TO_DEG;
    pitch = atan2f(-a[0], sqrtf(a[1] * a[1] + a[2] * a[2])) * RAD_TO_DEG;
  }
  yaw = 0;
  lastUs = micros();
}

void setup() {
  Serial.begin(115200);
  delay(1000);
  if (!findMPU(21, 22) && !findMPU(22, 23)) {
    Serial.println("# MPU6050 negasit nici pe SDA=21/SCL=22, nici pe SDA=22/SCL=23!");
    Serial.println("# Verifica: VCC la 3.3V, GND, SDA, SCL. Ruleaza testul 'scan'.");
    while (true) delay(1000);
  }
  writeReg(0x6B, 0x01);  // trezire, ceas de la giroscopul X
  writeReg(0x1A, 0x03);  // filtru trece-jos ~44 Hz
  writeReg(0x1B, 0x08);  // gyro +-500 dps
  writeReg(0x1C, 0x00);  // accel +-2g
  delay(100);

  uint8_t who = 0;
  if (readRegs(0x75, &who, 1)) Serial.printf("# WHO_AM_I = 0x%02X (MPU-6050 original: 0x68)\n", who);

  calibrate();
  Serial.println("# Taste: z = recalibreaza, r = Roll/Pitch/Yaw pe 0");
}

void loop() {
  while (Serial.available()) {
    char c = Serial.read();
    if (c == 'z') calibrate();
    else if (c == 'r') roll = pitch = yaw = 0;
  }

  float a[3], g[3];
  if (!readMPU(a, g)) {
    i2cErr++;
    delay(10);
    return;
  }
  for (int k = 0; k < 3; k++) g[k] -= gOff[k];

  uint32_t now = micros();
  float dt = (now - lastUs) / 1e6f;
  lastUs = now;

  float accRoll = atan2f(a[1], a[2]) * RAD_TO_DEG;
  float accPitch = atan2f(-a[0], sqrtf(a[1] * a[1] + a[2] * a[2])) * RAD_TO_DEG;
  roll = ALPHA * (roll + g[0] * dt) + (1 - ALPHA) * accRoll;
  pitch = ALPHA * (pitch + g[1] * dt) + (1 - ALPHA) * accPitch;
  yaw += g[2] * dt;

  static uint32_t lastPrint = 0;
  if (millis() - lastPrint >= 200) {
    lastPrint = millis();
    Serial.printf("Gx:%.1f,Gy:%.1f,Gz:%.1f,Ax:%.2f,Ay:%.2f,Az:%.2f,Roll:%.1f,Pitch:%.1f,Yaw:%.1f,I2C_err:%lu\n", g[0],
                  g[1], g[2], a[0], a[1], a[2], roll, pitch, yaw, (unsigned long)i2cErr);
  }
  delay(5);
}
