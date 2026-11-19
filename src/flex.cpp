#include <Arduino.h>
#include <Preferences.h>

// Divizor de tensiune: 3.3V -> senzor flex -> GPIO32 -> 3 x 10k in serie (30k) -> GND
#define FLEX_PIN 32
const float VCC = 3.3;
const float R_FIXED = 30000.0;  // 3 rezistente de 10k in serie
const float V_MIN = 0.16;  // sub ~0.15V ADC-ul ESP32 (atenuare 11dB) nu mai masoara corect

// Puncte de calibrare: unghi cunoscut -> rezistenta masurata
const int N_CAL = 3;
const float CAL_ANGLES[N_CAL] = {0, 45, 90};
const char CAL_KEYS[N_CAL] = {'0', '4', '9'};
float calR[N_CAL] = {NAN, NAN, NAN};

const float EMA_ALPHA = 0.2;  // netezire: mai mic = mai stabil, dar mai lent
float rFiltered = NAN;

Preferences prefs;

// Media "taiata" din 64 de citiri: aruncam sfertul cel mai mic si cel mai mare (zgomot, varfuri)
float readMilliVolts() {
  const int N = 64;
  uint16_t s[N];
  for (int i = 0; i < N; i++) s[i] = analogReadMilliVolts(FLEX_PIN);
  std::sort(s, s + N);
  uint32_t sum = 0;
  for (int i = N / 4; i < N - N / 4; i++) sum += s[i];
  return sum / (float)(N / 2);
}

void loadCalibration() {
  prefs.begin("flex", true);
  for (int i = 0; i < N_CAL; i++) calR[i] = prefs.getFloat(String(CAL_KEYS[i]).c_str(), NAN);
  prefs.end();
}

void saveCalibration(int i, float r) {
  calR[i] = r;
  prefs.begin("flex", false);
  prefs.putFloat(String(CAL_KEYS[i]).c_str(), r);
  prefs.end();
}

bool isCalibrated() {
  for (int i = 0; i < N_CAL; i++)
    if (isnan(calR[i])) return false;
  return true;
}

void printHelp() {
  Serial.println("Calibrare: pune degetul la unghiul dat si apasa tasta:");
  Serial.println("  0 = drept (0 grade), 4 = 45 grade, 9 = 90 grade, r = sterge calibrarea");
}

// Interpolare liniara pe bucati intre punctele de calibrare (si extrapolare la capete)
float resistanceToAngle(float r) {
  int seg = (r < calR[1]) ? 0 : 1;
  float t = (r - calR[seg]) / (calR[seg + 1] - calR[seg]);
  return CAL_ANGLES[seg] + t * (CAL_ANGLES[seg + 1] - CAL_ANGLES[seg]);
}

void handleSerial() {
  while (Serial.available()) {
    char c = Serial.read();
    if (c == 'r') {
      prefs.begin("flex", false);
      prefs.clear();
      prefs.end();
      for (int i = 0; i < N_CAL; i++) calR[i] = NAN;
      Serial.println("Calibrare stearsa.");
      printHelp();
      continue;
    }
    for (int i = 0; i < N_CAL; i++) {
      if (c == CAL_KEYS[i] && !isnan(rFiltered)) {
        saveCalibration(i, rFiltered);
        Serial.printf("Salvat %.0f grade = %.1f kOhm\n", CAL_ANGLES[i], rFiltered / 1000.0);
      }
    }
  }
}

void setup() {
  Serial.begin(115200);
  delay(1000);
  analogSetPinAttenuation(FLEX_PIN, ADC_11db);  // domeniu ~0-3.1V
  loadCalibration();
  if (isCalibrated())
    Serial.printf("Calibrare incarcata: 0=%.1fk 45=%.1fk 90=%.1fk\n",
                  calR[0] / 1000.0, calR[1] / 1000.0, calR[2] / 1000.0);
  printHelp();
}

void loop() {
  handleSerial();

  float v = readMilliVolts() / 1000.0;
  if (v < V_MIN || v > VCC - 0.05) {
    Serial.printf("V:%.2f -> verifica legaturile (3.3V -> flex -> D32 -> 30k -> GND)\n", v);
    rFiltered = NAN;
    delay(500);
    return;
  }

  // Rezistenta senzorului din divizor, apoi netezire exponentiala
  float r = R_FIXED * (VCC - v) / v;
  rFiltered = isnan(rFiltered) ? r : EMA_ALPHA * r + (1 - EMA_ALPHA) * rFiltered;

  if (isCalibrated()) {
    Serial.printf("R_kOhm:%.2f,Unghi:%.1f\n", rFiltered / 1000.0, resistanceToAngle(rFiltered));
  } else {
    Serial.printf("R_kOhm:%.2f (necalibrat)\n", rFiltered / 1000.0);
  }
  delay(50);
}
