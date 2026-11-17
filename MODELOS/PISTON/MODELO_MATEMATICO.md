# Modelo matemático del actuador electrohidráulico (un pistón)

Documenta el modelo de `MiL.slx` / `PiL.slx` (cilindro Rexroth CDH1 40/28 + válvula proporcional 4/3) y justifica las ganancias del PI de `ctrl_pi.slx`, que es el **controlador único del proyecto**: Kp = 27.5, Ki = 1, Ts = 10 ms (el mismo en los tres pistones de `ctrl_pi3.slx`). Kp = 20 salió del diseño de la sección 6; el 16 nov 2026 se subió a 27.5 (sección 6.1).

El diagrama de Simulink **no es lineal**: tiene saturación de la válvula, caudal ∝ √Δp, volúmenes que dependen de la posición V(x) y fricción F_f(ẋ). Solo hay función de transferencia tras linealizar. El modelo no lineal es el que se simula; el lineal sirve para analizar y sintonizar.

## 1. Parámetros

Fuente: `MODELOS/CINEMATICA/MARLUP_hydr_params.m` (lo carga `run_pil.m` y `demo_pil.m`).

| Símbolo | Valor | Descripción |
|---|---|---|
| m_L | 20 kg | Masa móvil |
| b | 1000 N·s/m | Fricción viscosa |
| β_e | 750 MPa | Módulo de compresibilidad efectivo |
| A_A | 12.57 cm² | Área del pistón (lado A, Ø40) |
| A_B | 6.41 cm² | Área del lado del vástago (Ø40/Ø28) |
| V_A0, V_B0 | 0.30 L, 0.15 L | Volúmenes muertos de cada cámara |
| carrera | 450 mm | |
| p_s | 160 bar | Presión de suministro |
| Q_N, Δp_N | 40 L/min, 35 bar | Caudal nominal de la válvula |
| τ_v, retardo | 2 ms, 1 ms | Dinámica de la válvula |

## 2. Ecuaciones (cada bloque del diagrama)

**Válvula** (primer orden con retardo), con $u\in[-1,1]$:

$$\frac{X_v(s)}{U(s)}=\frac{1}{\tau_v s+1}$$

**Orificios**: con $a(x_v)=w\,x_v$, el caudal es $Q = C_d\,a\sqrt{2\Delta p/\rho}$. Linealizado en el punto de operación:

$$Q_A = K_q x_v - K_c p_A,\qquad Q_B = -K_q x_v - K_c p_B$$

$$K_q = C_d w\sqrt{2\Delta p_0/\rho},\qquad K_c=\frac{C_d w\,x_{v0}}{\rho\sqrt{2\Delta p_0/\rho}}$$

**Cámaras** (continuidad con compresibilidad), con $C_A=V_{A0}/\beta_e$ y $C_B=V_{B0}/\beta_e$:

$$P_A=\frac{K_qX_v-A_A\,sX}{C_As+K_c},\qquad P_B=\frac{-K_qX_v+A_B\,sX}{C_Bs+K_c}$$

**Fuerza y carga**, con fricción viscosa $F_f\approx b\,\dot x$:

$$m_L s^2X+b\,sX = A_A P_A - A_B P_B$$

## 3. Función de transferencia de u a x (cilindro asimétrico)

$$G(s)=\frac{X(s)}{U(s)}=\frac{N(s)}{s\,(\tau_v s+1)\,\Delta(s)}$$

$$N(s)=K_q\big[(A_AC_B+A_BC_A)\,s+K_c(A_A+A_B)\big]$$

$$\Delta(s)=(m_Ls+b)(C_As+K_c)(C_Bs+K_c)+A_A^2(C_Bs+K_c)+A_B^2(C_As+K_c)$$

### Caso simétrico ($A_A=A_B=A$, $V_{A0}=V_{B0}=V_0$)

El cero se cancela:

$$G(s)=\frac{2AK_q}{s(\tau_vs+1)\left[m_LC\,s^2+(m_LK_c+bC)\,s+bK_c+2A^2\right]}$$

Si $bK_c\ll 2A^2$, queda la forma clásica:

$$G(s)\approx\frac{K_q/A}{s(\tau_vs+1)\left(\dfrac{s^2}{\omega_h^2}+\dfrac{2\zeta_h}{\omega_h}s+1\right)}$$

$$\omega_h=\sqrt{\frac{2A^2\beta_e}{m_LV_0}},\qquad \zeta_h=\frac{\omega_h\,(m_LK_c+bV_0/\beta_e)}{4A^2}$$

Para $K_c\approx0$ (válvula de centro crítico ideal), el amortiguamiento lo da casi solo la fricción: $\zeta_h\approx b/(2m_L\omega_h)$.

## 4. Función de transferencia identificada

Los valores analíticos de la sección 3 dependen de $K_q$, $K_c$ y los volúmenes, que no se midieron. Por eso $G(s)$ se identificó con un **ensayo en lazo abierto sobre el modelo no lineal de Simulink** (`diseno_pi.m`): escalones de $u=\pm0.02,\pm0.05,\pm0.1$ en $x_0=0.23$ m y medición de la velocidad del vástago. La velocidad se establece en ~25 ms **sin oscilar**: en el modelo simulado no aparece la resonancia hidráulica que predice la sección 3. Queda

$$G(s)\approx\frac{K_v\,e^{-\theta s}}{s(\tau s+1)}=\frac{0.636\,e^{-0.0088s}}{s(0.0085s+1)}$$

| Cantidad | Valor | Comentario |
|---|---|---|
| $K_v$ (señal pequeña) | **0.636 m/s** por unidad de $u$ | Promedio de extensión (0.740) y retracción (0.532), por las áreas distintas |
| $K_v$ a $u=\pm1$ | 0.43 / 0.29 m/s | Cae por la ecuación de orificio (√Δp) |
| $\tau$ | **8.5 ms** | Constante de tiempo de la velocidad |
| $\theta$ | **8.8 ms** | Retardo equivalente (válvula y compresibilidad) |

Para el diseño se discretiza con retenedor de orden cero a $T_s=10$ ms. El modelo lineal reproduce la respuesta al escalón del modelo no lineal (`figuras/pi_final_escalon.png`).

## 5. Lazo cerrado con el PI

Controlador: $C(s)=K_p+K_i/s$, integrador trapezoidal, anti-windup por *clamping*, $|u|\le1$. El lazo abierto es **tipo 2** (integrador del pistón y del PI): error nulo ante escalones y rampas de referencia.

## 6. Diseño y justificación de las ganancias: Kp = 20, Ki = 1

**Especificaciones:** $M_p\le10$ %, $t_s(2\%)\le2$ s, $|e_{ss}|<2.3$ mm, margen de ganancia ≥ 10 dB y de fase ≥ 60°. Deben cumplirse con la $G(s)$ identificada y con el modelo no lineal en dos escalones: 10 mm en $x_0$ (nivelación) y 0 → 0.40 m (validación unitaria, con la válvula saturada).

**Procedimiento** (`diseno_pi.m`): 14 candidatos (los PI que se usaban, `pidtune` con varios cruces y márgenes, y Ziegler–Nichols). La regla, fijada antes de correr, elige al que cumple todo con menor $t_s$ en el escalón de 10 mm y, si empatan, menor $M_p$. Solo tres cumplieron; ganó **Kp = 20, Ki = 1**.

| Respuesta | $M_p$ | $t_r$ | $t_s$ | $\lvert e_{ss}\rvert$ |
|---|---|---|---|---|
| Lineal, $G(s)$ | 0.4 % | 0.11 s | 0.22 s | 0 |
| No lineal, escalón de 10 mm | 2.4 % | 0.07 s | 0.28 s | 0.08 mm |
| No lineal, 0 → 0.40 m | 0.1 % | 0.73 s | 0.96 s | 0.19 mm |

- **Márgenes:** cruce en 12.6 rad/s, margen de fase 73.7°, de ganancia 16.9 dB (ganancia última ≈ 140).
- **Seguimiento del oleaje:** a 0.63 rad/s el error de seguimiento del lazo cerrado es 4.9 %.
- **Ki = 1:** el cero del PI está en $K_i/K_p=0.05$ rad/s, dos décadas bajo el cruce: no cambia el margen ni el sobrepaso; anula el error ante perturbaciones lentas (carga, sesgo de la válvula).
- **Escalón grande:** la válvula satura, el pistón avanza a ≈ 0.43 m/s y el $t_s$ (0.96 s) lo fija el caudal máximo, no $K_p$.
- **Cuantización:** un paso del ADC (0.44 mm) da $\Delta u=K_p\cdot0.44$ mm ≈ 0.009, una cuenta del PWM de 8 bits.
- **Por qué no los anteriores:** Kp = 6.7 no entra en la banda del 2 % en el escalón pequeño y deja 3.4 mm de error en el grande; Kp = 60 da 61 % de sobrepaso en el escalón pequeño con 44° de margen de fase.

### 6.1 Actualización: Kp = 27.5 (16 nov 2026)

Con la arquitectura B (prealimentación pura), el residuo de la mesa es el atraso de los pistones al seguir la ola, así que conviene el PI más rápido que todavía cumpla la regla de arriba. `MODELOS/CINEMATICA/exp11_opt_prealimentacion.m` buscó en el modelo no lineal el mayor $K_p$ que la cumple: con 160 bar es **Kp = 27.5, Ki = 1**. Ki alto (32–48) seguiría mejor la ola, pero sobrepasa 13–28 % en el escalón de 10 mm.

| Respuesta (Kp = 27.5, Ki = 1) | $M_p$ | $t_s$ | $\lvert e_{ss}\rvert$ |
|---|---|---|---|
| Lineal, $G(s)$ | 0.4 % | 0.13 s | 0 |
| No lineal, escalón de 10 mm | 7.5 % | 0.21 s | 0.09 mm |
| No lineal, 0 → 0.40 m | 0.8 % | 0.95 s | — |

Márgenes: 14.1 dB de ganancia y 67.9° de fase. En la plataforma completa baja el pico de pitch de la mesa de 0.449° a 0.349° en el caso nominal y de 2.28° a 1.79° con la base a 15°. La validación unitaria (`run_pil`) y las figuras de este documento siguen siendo las de Kp = 20.

### Muestreo

$T_s=10$ ms frente a un cruce de 12.6 rad/s (unas 25 muestras por periodo del cruce) y al retardo de 8.8 ms de la planta.

## 7. Supuestos y puntos abiertos

- **Identificación en un punto:** $x_0=0.23$ m y señal pequeña. A válvula abierta $K_v$ baja hasta 0.29 m/s (retracción); el diseño se verificó igual con el escalón grande.
- **Resonancia hidráulica:** el análisis de la sección 3 predice $\omega_h\approx548$ rad/s con $\zeta_h\approx0.05$, pero el modelo simulado no la muestra. Si el actuador real la tiene, habrá que revisar el margen de ganancia.
- **Plataforma completa:** el mismo PI se usa en `ctrl_pi3.slx` con el lazo de nivelación K = 15 (ver `MODELOS/CINEMATICA/BITACORA.md`).
