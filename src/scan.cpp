#include <Arduino.h>
#include <Wire.h>
void scan(int sda, int scl) {
  Wire.end(); Wire.begin(sda, scl); delay(100);
  Serial.printf("SDA=%d SCL=%d:", sda, scl);
  for (uint8_t a = 1; a < 127; a++) { Wire.beginTransmission(a); if (Wire.endTransmission() == 0) Serial.printf(" 0x%02X", a); }
  Serial.println();
}
void setup() { Serial.begin(115200); delay(1000); }
void loop() { scan(22, 23); scan(23, 22); scan(21, 22); delay(1000); }
