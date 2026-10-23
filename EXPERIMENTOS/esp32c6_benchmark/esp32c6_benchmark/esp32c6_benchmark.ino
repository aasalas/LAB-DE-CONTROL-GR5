// Benchmark del ESP32-C6 para el PiL de MARLUP: aritmetica, paso del PI, lazo en tiempo
// real, ADC y respuesta a tramas por USB. Los tiempos se miden con el contador de ciclos.
// Comandos por el puerto serie (USB-Serial/JTAG):
//   'A' aritmetica   'P' paso del PI   'L' lazo en tiempo real   'D' ADC
//   0xAA x_lo x_hi r_lo r_hi xor  -> responde 0x55 u_lo u_hi seq est xor (eco para medir RTT)
// Cada prueba imprime lineas CSV y termina con "DONE,<prueba>".
#include <Arduino.h>
#include "esp_cpu.h"
#include "pi.h"

static inline uint32_t ciclos() { return esp_cpu_get_cycle_count(); }
static uint32_t MHZ = 160;

// ---------------- 'A': aritmetica ----------------
volatile int32_t vi = 7; volatile float vf = 1.0001f; volatile double vd = 1.0001;
template <typename F> void medir(const char *op, uint32_t n, F cuerpo) {
  uint32_t t0 = ciclos();
  cuerpo(n);
  uint32_t dc = ciclos() - t0;
  double ns = dc * 1000.0 / MHZ / n;
  Serial.printf("ARIT,%s,%.3f,%.3f\n", op, ns, 1000.0 / ns);   // ns por operacion, Mops/s
}
void prueba_aritmetica() {
  const uint32_t N = 1000000;
  medir("int32 mul+add", N, [](uint32_t n) { int32_t a = 1, b = vi; for (uint32_t i = 0; i < n; i++) a = a * b + 3; vi = a; });
  medir("float mul+add", N, [](uint32_t n) { float a = 1, b = vf; for (uint32_t i = 0; i < n; i++) a = a * b + 0.5f; vf = a; });
  medir("double mul+add", N / 4, [](uint32_t n) { double a = 1, b = vd; for (uint32_t i = 0; i < n; i++) a = a * b + 0.5; vd = a; });
  medir("float div", N / 4, [](uint32_t n) { float a = 1e6f, b = vf; for (uint32_t i = 0; i < n; i++) a = a / b + 1.0f; vf = a; });
  medir("double div", N / 10, [](uint32_t n) { double a = 1e6, b = vd; for (uint32_t i = 0; i < n; i++) a = a / b + 1.0; vd = a; });
  medir("sqrtf", N / 4, [](uint32_t n) { float a = 0; for (uint32_t i = 0; i < n; i++) a += sqrtf(vf + i); vf = a; });
  Serial.println("DONE,A");
}

// ---------------- 'P': duracion de un paso del PI ----------------
void prueba_pi() {
  const int N = 2000;
  uint32_t vacio = UINT32_MAX;                      // costo de leer el contador dos veces
  for (int i = 0; i < 100; i++) { uint32_t a = ciclos(); uint32_t b = ciclos(); vacio = min(vacio, b - a); }
  PIf sf; PId sd; volatile float uf; volatile double ud;
  for (int i = 0; i < N; i++) {                     // referencia y posicion variando como en un escalon
    float r = 0.40f, x = 0.40f * (1.0f - expf(-i / 300.0f)) + 0.0005f * sinf(i);
    uint32_t a = ciclos(); uf = pi_f(sf, r, x); uint32_t b = ciclos();
    uint32_t c = ciclos(); ud = pi_d(sd, (double)r, (double)x); uint32_t d = ciclos();
    Serial.printf("PI,%d,%u,%u\n", i, (b - a) - vacio, (d - c) - vacio);   // ciclos float, double
  }
  Serial.printf("PIINFO,%u,%u\n", MHZ, vacio);
  Serial.println("DONE,P");
}

// ---------------- 'L': lazo periodico en tiempo real ----------------
static uint32_t lat[20000];
int cmp_u32(const void *a, const void *b) { uint32_t x = *(const uint32_t *)a, y = *(const uint32_t *)b; return (x > y) - (x < y); }

void lazo(const char *var, uint32_t hz) {
  const uint32_t per = MHZ * 1000000UL / hz;
  const uint32_t N = min<uint32_t>(20000, max<uint32_t>(hz / 2, 500));   // ~0.5 s, entre 500 y 20000 ciclos
  PIf sf; PId sd; volatile float u = 0; uint32_t perdidos = 0;
  uint32_t next = ciclos() + per, t_ini = next;
  for (uint32_t i = 0; i < N; i++) {
    while ((int32_t)(ciclos() - next) < 0) {}
    uint32_t t0 = ciclos();
    lat[i] = t0 - next;
    float x = 0.39f;
    if (var[0] == 'a') x = analogRead(A0) * (0.45f / 4095.0f);   // "adc+pi": lectura real del ADC
    if (var[0] == 'd') u = (float)pi_d(sd, 0.40, (double)x);
    else u = pi_f(sf, 0.40f, x);
    next += per;
    if (lat[i] > per) { perdidos++; next = ciclos() + per; }       // plazo perdido: se re-sincroniza
  }
  double seg = (double)(ciclos() - t_ini) / (MHZ * 1e6);
  qsort(lat, N, sizeof(uint32_t), cmp_u32);
  double sum = 0; for (uint32_t i = 0; i < N; i++) sum += lat[i];
  auto us = [](uint32_t c) { return c / (double)MHZ; };
  Serial.printf("LOOP,%s,%u,%u,%.1f,%.3f,%.3f,%.3f,%.3f,%.2f\n", var, hz, N, N / seg,
                sum / N / MHZ, us(lat[N / 2]), us(lat[(N * 99) / 100]), us(lat[N - 1]), 100.0 * perdidos / N);
}
void prueba_lazo() {
  const uint32_t tasas[] = {1000, 2000, 5000, 10000, 20000, 50000, 100000, 200000, 500000, 1000000};
  for (const char *var : {"float", "double", "adc+pi"})
    for (uint32_t hz : tasas) lazo(var, hz);
  Serial.println("DONE,L");
}

// ---------------- 'D': ADC ----------------
void prueba_adc() {
  const int N = 5000;
  static uint16_t v[N];
  uint32_t t0 = ciclos();
  for (int i = 0; i < N; i++) v[i] = analogRead(A0);
  double us = (ciclos() - t0) / (double)MHZ / N;
  double m = 0, s2 = 0; uint16_t mn = 4095, mx = 0;
  for (int i = 0; i < N; i++) { m += v[i]; mn = min(mn, v[i]); mx = max(mx, v[i]); }
  m /= N;
  for (int i = 0; i < N; i++) s2 += (v[i] - m) * (v[i] - m);
  Serial.printf("ADC,%d,%.3f,%.1f,%.2f,%.2f,%u,%u\n", A0, us, 1e6 / us, m, sqrt(s2 / N), mn, mx);
  Serial.println("DONE,D");
}

// ---------------- eco de tramas (RTT por USB) ----------------
PIf pie; uint8_t seq = 0;
void eco(uint8_t h) {
  uint8_t b[5];
  for (int i = 0; i < 5; i++) { uint32_t t = millis(); while (!Serial.available()) if (millis() - t > 50) return; b[i] = Serial.read(); }
  uint8_t chk = h ^ b[0] ^ b[1] ^ b[2] ^ b[3];
  float x = (b[0] | (b[1] << 8)) * 1e-5f, r = (b[2] | (b[3] << 8)) * 1e-5f;
  int16_t ui = (int16_t)lroundf(pi_f(pie, r, x) * 32767.0f);
  uint8_t f[6] = {0x55, (uint8_t)(ui & 0xFF), (uint8_t)(ui >> 8), seq++, (uint8_t)(chk != b[4]), 0};
  f[5] = f[0] ^ f[1] ^ f[2] ^ f[3] ^ f[4];
  Serial.write(f, 6);
  Serial.flush();
}

void setup() {
  Serial.begin(115200);
  MHZ = getCpuFrequencyMhz();
  analogReadResolution(12);
}

void loop() {
  if (!Serial.available()) return;
  uint8_t c = Serial.read();
  switch (c) {
    case 'A': prueba_aritmetica(); break;
    case 'P': prueba_pi(); break;
    case 'L': prueba_lazo(); break;
    case 'D': prueba_adc(); break;
    case 'I': Serial.printf("INFO,%s,%u MHz,%u B libres\n", ESP.getChipModel(), MHZ, ESP.getFreeHeap()); Serial.println("DONE,I"); break;
    case 0xAA: eco(c); break;
  }
}
