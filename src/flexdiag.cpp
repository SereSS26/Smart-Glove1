#include <Arduino.h>

// Diagnostic pentru legaturile senzorului flex pe GPIO32
#define FLEX_PIN 32

int readMv() {
  uint32_t s = 0;
  for (int i = 0; i < 32; i++) s += analogReadMilliVolts(FLEX_PIN);
  return s / 32;
}

void setup() {
  Serial.begin(115200);
  delay(1000);
  analogSetPinAttenuation(FLEX_PIN, ADC_11db);
}

void loop() {
  pinMode(FLEX_PIN, INPUT);
  delay(20);
  int normal = readMv();
  pinMode(FLEX_PIN, INPUT_PULLUP);  // rezistenta interna ~45k spre 3.3V
  delay(20);
  int pullup = readMv();
  pinMode(FLEX_PIN, INPUT_PULLDOWN);  // rezistenta interna ~45k spre GND
  delay(20);
  int pulldown = readMv();
  pinMode(FLEX_PIN, INPUT);
  Serial.printf("normal:%dmV pullup:%dmV pulldown:%dmV\n", normal, pullup, pulldown);
  delay(500);
}
