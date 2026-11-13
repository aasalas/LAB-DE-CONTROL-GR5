// MARLUP - PiL de 3 pistones: tres lazos PI (Tustin + anti-windup por clamping) en un Arduino UNO.
// Es la version 2 del protocolo de pil_arduino.ino: una sola trama lleva los 3 pistones.
//
// Simulink -> Arduino (14 bytes):
//   0xAA | x1 x2 x3 (3 x uint16) | r1 r2 r3 (3 x uint16) | XOR
//   x, r: posicion medida y referencia en unidades de 0.01 mm, little-endian
// Arduino -> Simulink (10 bytes):
//   0x55 | u1 u2 u3 (3 x int16) | seq | estado | XOR
//   u: comando escalado (u*32767), little-endian; estado: 0 ok, 1 checksum malo
// Configuracion y reinicio (14 bytes):
//   0xA5 | Kp Ki Usat (3 x float32, little-endian) | XOR
//   Fija las ganancias, pone en cero los estados y responde 10 bytes con encabezado 0x5A
//   (estado 0 si se acepto, 1 si el checksum o las ganancias eran invalidos).
//
// Las ganancias se mandan desde MATLAB (pil3_iniciar.m): no hay que volver a subir el
// programa para probar otro Kp o Ki. Los valores de abajo solo rigen hasta la primera
// trama de configuracion.
//
// Tiempo en el cable a 115200 baud: (14 + 10) bytes * 10 bits / 115200 = 2.1 ms de 10 ms.

const uint8_t H_IN = 0xAA, H_OUT = 0x55, H_CFG = 0xA5, H_ACK = 0x5A;
const uint8_t N = 3;                 // pistones
const uint8_t LEN_IN = 14;           // largo de la trama de entrada y de configuracion
const float Ts = 0.01f;              // periodo de muestreo [s]

float Kp = 60.0f, Ki = 1.0f, USAT = 1.0f;

float I1[N], e1[N], ulast[N];
uint8_t seq = 0;

void limpiar() {
  for (uint8_t i = 0; i < N; i++) { I1[i] = 0.0f; e1[i] = 0.0f; ulast[i] = 0.0f; }
  seq = 0;
}

void enviar(uint8_t h, const float *u, uint8_t est) {
  uint8_t f[10];
  f[0] = h;
  for (uint8_t i = 0; i < N; i++) {
    int16_t v = (int16_t)lroundf(u[i] * 32767.0f);
    f[1 + 2 * i] = (uint8_t)(v & 0xFF);
    f[2 + 2 * i] = (uint8_t)((v >> 8) & 0xFF);
  }
  f[7] = seq;
  f[8] = est;
  uint8_t c = 0;
  for (uint8_t i = 0; i < 9; i++) c ^= f[i];
  f[9] = c;
  Serial.write(f, 10);
}

void setup() {
  Serial.begin(115200);
  pinMode(LED_BUILTIN, OUTPUT);      // LED 13 encendido = alguna valvula saturada
  limpiar();
}

void loop() {
  if (Serial.available() < 1) return;
  uint8_t h = Serial.read();
  if (h != H_IN && h != H_CFG) return;           // resincroniza

  uint8_t b[LEN_IN - 1];
  for (uint8_t i = 0; i < LEN_IN - 1; i++) {
    unsigned long t0 = millis();
    while (Serial.available() < 1) { if (millis() - t0 > 50) return; }
    b[i] = Serial.read();
  }

  uint8_t chk = h;                               // XOR de todo menos el ultimo byte
  for (uint8_t i = 0; i < LEN_IN - 2; i++) chk ^= b[i];
  bool ok = (chk == b[LEN_IN - 2]);

  if (h == H_CFG) {
    static const float ceros[N] = {0.0f, 0.0f, 0.0f};
    float g[3];
    memcpy(g, b, sizeof(g));
    bool valido = ok && (g[0] >= 0.0f) && (g[1] >= 0.0f) && (g[2] > 0.0f) && (g[2] <= 1.0f);
    if (valido) {                                // la comparacion con NaN da falso: se rechaza
      Kp = g[0]; Ki = g[1]; USAT = g[2];
      limpiar();
      digitalWrite(LED_BUILTIN, LOW);
    }
    enviar(H_ACK, ceros, valido ? 0 : 1);
    return;
  }

  if (!ok) {                                     // trama corrupta: repite los u anteriores
    enviar(H_OUT, ulast, 1);
    return;
  }

  float u[N];
  bool sat = false;
  for (uint8_t i = 0; i < N; i++) {
    uint16_t xi = (uint16_t)b[2 * i]     | ((uint16_t)b[2 * i + 1] << 8);
    uint16_t ri = (uint16_t)b[6 + 2 * i] | ((uint16_t)b[7 + 2 * i] << 8);
    float e  = (float)ri * 1e-5f - (float)xi * 1e-5f;     // referencia - posicion [m]
    float In = I1[i] + Ki * Ts * 0.5f * (e + e1[i]);      // integral por Tustin
    float v  = Kp * e + In;
    float ui = v;
    if (ui >  USAT) ui =  USAT;
    if (ui < -USAT) ui = -USAT;
    if (!((v > USAT && e > 0) || (v < -USAT && e < 0))) I1[i] = In;   // clamping
    e1[i] = e;
    u[i] = ui;
    ulast[i] = ui;
    if (ui >= USAT || ui <= -USAT) sat = true;
  }
  digitalWrite(LED_BUILTIN, sat ? HIGH : LOW);
  seq++;
  enviar(H_OUT, u, 0);
}
