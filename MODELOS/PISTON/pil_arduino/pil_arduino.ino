// MARLUP - Controlador PI (Tustin + anti-windup por clamping) para Processor-in-the-Loop
// Trama Simulink -> Arduino (6 bytes): 0xAA | x_lo | x_hi | r_lo | r_hi | XOR
//   x, r: posicion y referencia en unidades de 0.01 mm (uint16)
// Trama Arduino -> Simulink (6 bytes): 0x55 | u_lo | u_hi | seq | estado | XOR
//   u: comando en int16 escalado (u*32767), estado: 0 ok, 1 checksum malo
// Trama de reinicio: 0xA5 + 5 bytes cualquiera -> responde 0x5A ... (estados a cero)

const uint8_t H_IN = 0xAA, H_OUT = 0x55, H_RST = 0xA5, H_ACK = 0x5A;
const float Kp = 60.0f, Ki = 1.0f, Ts = 0.01f;
const float USAT = 1.0f;

float I1 = 0.0f, e1 = 0.0f, ulast = 0.0f;
uint8_t seq = 0;

void enviar(uint8_t h, int16_t ui, uint8_t est) {
  uint8_t f[6];
  f[0] = h;
  f[1] = (uint8_t)(ui & 0xFF);
  f[2] = (uint8_t)((ui >> 8) & 0xFF);
  f[3] = seq;
  f[4] = est;
  f[5] = f[0] ^ f[1] ^ f[2] ^ f[3] ^ f[4];
  Serial.write(f, 6);
}

void setup() {
  Serial.begin(115200);
}

void loop() {
  if (Serial.available() < 1) return;
  uint8_t h = Serial.read();
  if (h != H_IN && h != H_RST) return;          // resincroniza
  uint8_t b[5];
  for (uint8_t i = 0; i < 5; i++) {
    unsigned long t0 = millis();
    while (Serial.available() < 1) { if (millis() - t0 > 50) return; }
    b[i] = Serial.read();
  }
  if (h == H_RST) {                              // reinicio de estados
    I1 = 0.0f; e1 = 0.0f; ulast = 0.0f; seq = 0;
    enviar(H_ACK, 0, 0);
    return;
  }
  uint8_t chk = h ^ b[0] ^ b[1] ^ b[2] ^ b[3];
  if (chk != b[4]) {                             // trama corrupta: repite u anterior
    enviar(H_OUT, (int16_t)(ulast * 32767.0f), 1);
    return;
  }
  float x = (float)((uint16_t)b[0] | ((uint16_t)b[1] << 8)) * 1e-5f;  // m
  float r = (float)((uint16_t)b[2] | ((uint16_t)b[3] << 8)) * 1e-5f;  // m
  float e = r - x;
  float In = I1 + Ki * Ts * 0.5f * (e + e1);     // integral por Tustin
  float v = Kp * e + In;
  float u = v;
  if (u > USAT) u = USAT;
  if (u < -USAT) u = -USAT;
  if (!((v > USAT && e > 0) || (v < -USAT && e < 0))) I1 = In;  // clamping
  e1 = e; ulast = u;
  seq++;
  enviar(H_OUT, (int16_t)lroundf(u * 32767.0f), 0);
}
