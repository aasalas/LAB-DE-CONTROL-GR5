// PI del proyecto: Tustin + anti-windup por clamping (Kp = 60, Ki = 1, Ts = 10 ms, sat +-1).
// En un header para que el preprocesador del .ino no genere prototipos antes de los structs.
#pragma once

struct PIf { float I1 = 0, e1 = 0; };
struct PId { double I1 = 0, e1 = 0; };

static inline float pi_f(PIf &s, float r, float x) {
  const float Kp = 60.0f, Ki = 1.0f, Ts = 0.01f;
  float e = r - x, In = s.I1 + Ki * Ts * 0.5f * (e + s.e1), v = Kp * e + In, u = v;
  if (u > 1.0f) u = 1.0f;
  if (u < -1.0f) u = -1.0f;
  if (!((v > 1.0f && e > 0) || (v < -1.0f && e < 0))) s.I1 = In;
  s.e1 = e;
  return u;
}

static inline double pi_d(PId &s, double r, double x) {
  const double Kp = 60.0, Ki = 1.0, Ts = 0.01;
  double e = r - x, In = s.I1 + Ki * Ts * 0.5 * (e + s.e1), v = Kp * e + In, u = v;
  if (u > 1.0) u = 1.0;
  if (u < -1.0) u = -1.0;
  if (!((v > 1.0 && e > 0) || (v < -1.0 && e < 0))) s.I1 = In;
  s.e1 = e;
  return u;
}
