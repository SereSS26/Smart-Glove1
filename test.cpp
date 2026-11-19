#include <Wire.h>

void setup() {
  Serial.begin(115200);
  Wire.begin(22, 23);
  delay(500);
  for (byte a = 1; a < 127; a++) {
    Wire.beginTransmission(a);
    if (Wire.endTransmission() == 0) {
      Serial.print("Gasit dispozitiv la 0x");
      Serial.println(a, HEX);
    }
  }
  Serial.println("Scanare terminata");
}

void loop() {}