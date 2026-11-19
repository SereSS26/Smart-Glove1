#include <Arduino.h>
#include <Wire.h>

// Conexiuni: SDA -> GPIO22, SCL -> GPIO23
#define SDA_PIN 22
#define SCL_PIN 23

uint8_t mpuAddr = 0x68;  // 0x69 daca AD0 e legat la 3.3V

// Offset-uri calculate la calibrare
float gxOff = 0, gyOff = 0, gzOff = 0;
float axOff = 0, ayOff = 0, azOff = 0;

// Unghiuri estimate (grade)
float roll = 0, pitch = 0, yaw = 0;
unsigned long lastMicros = 0;

const float ALPHA = 0.98;  // filtru complementar: cat de mult ne bazam pe giroscop

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

// Citeste accel (g) si gyro (dps), fara offset-uri
bool readMPU(float &ax, float &ay, float &az, float &gx, float &gy, float &gz) {
  uint8_t d[14];
  if (!readRegs(0x3B, d, 14)) return false;
  ax = (int16_t)((d[0] << 8) | d[1]) / 16384.0;
  ay = (int16_t)((d[2] << 8) | d[3]) / 16384.0;
  az = (int16_t)((d[4] << 8) | d[5]) / 16384.0;
  gx = (int16_t)((d[8] << 8) | d[9]) / 131.0;
  gy = (int16_t)((d[10] << 8) | d[11]) / 131.0;
  gz = (int16_t)((d[12] << 8) | d[13]) / 131.0;
  return true;
}

// Senzorul trebuie sa stea nemiscat, orizontal (Z in sus)
void calibrate() {
  const int N = 1000;
  Serial.println("Calibrare: nu misca senzorul...");
  float sax = 0, say = 0, saz = 0, sgx = 0, sgy = 0, sgz = 0;
  int ok = 0;
  for (int i = 0; i < N; i++) {
    float ax, ay, az, gx, gy, gz;
    if (readMPU(ax, ay, az, gx, gy, gz)) {
      sax += ax; say += ay; saz += az;
      sgx += gx; sgy += gy; sgz += gz;
      ok++;
    }
    delay(2);
  }
  gxOff = sgx / ok; gyOff = sgy / ok; gzOff = sgz / ok;
  axOff = sax / ok; ayOff = say / ok; azOff = saz / ok - 1.0;  // pe Z trebuie sa ramana 1g
  Serial.printf("Offset gyro [dps]: %.2f %.2f %.2f\n", gxOff, gyOff, gzOff);
  Serial.printf("Offset accel [g]:  %.3f %.3f %.3f\n", axOff, ayOff, azOff);
}

void setup() {
  Serial.begin(115200);
  delay(1000);
  Wire.begin(SDA_PIN, SCL_PIN);
  Wire.setClock(400000);

  Wire.beginTransmission(mpuAddr);
  if (Wire.endTransmission() != 0) {
    mpuAddr = 0x69;
    Wire.beginTransmission(mpuAddr);
    if (Wire.endTransmission() != 0) {
      Serial.println("MPU6050 negasit! Verifica firele (SDA=22, SCL=23, VCC=3.3V, GND).");
      while (true) delay(1000);
    }
  }

  writeReg(0x6B, 0x01);  // PWR_MGMT_1: trezire, ceas de la giroscopul X (mai stabil)
  writeReg(0x1A, 0x03);  // CONFIG: filtru digital trece-jos ~44 Hz
  writeReg(0x1B, 0x00);  // gyro +-250 dps
  writeReg(0x1C, 0x00);  // accel +-2g
  delay(100);

  calibrate();
  lastMicros = micros();
}

void loop() {
  float ax, ay, az, gx, gy, gz;
  if (!readMPU(ax, ay, az, gx, gy, gz)) {
    Serial.println("Eroare citire");
    delay(500);
    return;
  }
  ax -= axOff; ay -= ayOff; az -= azOff;
  gx -= gxOff; gy -= gyOff; gz -= gzOff;

  unsigned long now = micros();
  float dt = (now - lastMicros) / 1e6;
  lastMicros = now;

  // Unghiuri din accelerometru (corecte doar cand senzorul nu accelereaza)
  float accRoll = atan2(ay, az) * RAD_TO_DEG;
  float accPitch = atan2(-ax, sqrt(ay * ay + az * az)) * RAD_TO_DEG;

  // Filtru complementar: giroscop pe termen scurt, accelerometru pe termen lung
  roll = ALPHA * (roll + gx * dt) + (1 - ALPHA) * accRoll;
  pitch = ALPHA * (pitch + gy * dt) + (1 - ALPHA) * accPitch;
  yaw += gz * dt;  // fara magnetometru, yaw va deriva in timp

  static unsigned long lastPrint = 0;
  if (millis() - lastPrint >= 50) {
    lastPrint = millis();
    // Format compatibil cu Serial Plotter / Teleplot
    Serial.printf("Roll:%.1f,Pitch:%.1f,Yaw:%.1f\n", roll, pitch, yaw);
  }
  delay(5);
}
