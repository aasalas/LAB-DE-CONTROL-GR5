# Modelo matemático del actuador electrohidráulico (un pistón)

Documenta el modelo de `MiL.slx` / `PiL.slx` (cilindro Rexroth CDH1 40/28 + válvula proporcional 4/3) y justifica las ganancias del PI de `ctrl_pi.slx` (Kp = 60, Ki = 1, Ts = 10 ms).

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

## 4. Valores numéricos

Con los parámetros de la sección 1 y $K_c\approx0$:

| Cantidad | Valor | Comentario |
|---|---|---|
| $K_v=K_q/A\approx Q_N/A_A$ | **0.53 m/s** por unidad de $u$ | Velocidad máxima a $u=1$. Es una estimación a partir del caudal nominal; no se midió |
| $\omega_h$ (asimétrico, $A_A^2/C_A+A_B^2/C_B$) | **≈ 548 rad/s** (87 Hz) | El informe usa ≈ 390 rad/s (62 Hz): ver sección 7 |
| $\zeta_h$ | **≈ 0.046** | Muy poco amortiguado |
| Tiempo de recorrido a $u=1$ | 0.4 m / 0.53 m/s ≈ **0.75 s** | |

## 5. Lazo cerrado con el PI

Controlador: $C(s)=K_p+K_i/s$, realimentación unitaria. Con $G=N/[s(\tau_vs+1)\Delta]$:

$$T(s)=\frac{X}{X_{ref}}=\frac{(K_ps+K_i)\,N(s)}{s^2(\tau_vs+1)\Delta(s)+(K_ps+K_i)\,N(s)}$$

En el caso simétrico simplificado:

$$T(s)=\frac{(K_ps+K_i)K_v}{s^2(\tau_vs+1)\left(\frac{s^2}{\omega_h^2}+\frac{2\zeta_h}{\omega_h}s+1\right)+(K_ps+K_i)K_v}$$

El lazo abierto es **tipo 2**: un integrador del pistón y otro del PI.

## 6. Justificación de las ganancias

### Kp = 60

**Error en estado estacionario.**
- Ante un escalón, $e_{ss}=0$ con cualquier $K_p$, porque la planta ya integra.
- Ante una rampa de velocidad $v_r$, un P solo deja $e_{ss}=v_r/(K_pK_v)$. Con $K_pK_v\approx31.8\ \text{s}^{-1}$, una rampa de 10 mm/s da 0.31 mm, muy por debajo del requisito de 2.3 mm.
- El paso del ADC (0.44 mm) se traduce en $\Delta u=K_p\cdot0.44\ \text{mm}\approx0.026$, unas 3 cuentas del PWM de 8 bits. Subir $K_p$ amplifica la cuantización en el comando.

**Tiempo de asentamiento.**
- En la zona lineal, el polo dominante está en $s\approx-K_pK_v=-31.8$: $\tau\approx31$ ms y $t_s(2\%)\approx4/(K_pK_v)\approx0.13$ s.
- El $t_s$ medido es **1.05 s** porque con un escalón de 0.40 m la válvula satura: $u=1$ mientras $e>1/K_p=16.7$ mm y el pistón avanza a velocidad máxima (≈ 0.75 s). Coincide con $t_r=0.73$ s.
- Es decir, el $t_s$ lo fija el caudal máximo de la válvula, no $K_p$. Subirlo solo acorta el tramo lineal final.

**Estabilidad.** Con $\tau_v=2$ ms, retardo de válvula de 1 ms, retardo de muestreo $T_s/2$ y la resonancia con $\zeta_h=0.046$ (inversión de fase cerca de 194 rad/s):

| $K_p$ | Margen de fase | Margen de ganancia | $t_s$ lineal | Banda de saturación |
|---|---|---|---|---|
| 10 | 87° | 31 dB | 0.75 s | 100 mm |
| 30 | 83° | 21 dB | 0.25 s | 33 mm |
| **60** | **75°** | **15 dB** | **0.13 s** | **16.7 mm** |
| 100 | 65° | 11 dB | 0.075 s | 10 mm |
| 150 | 53° | 7 dB | 0.05 s | 6.7 mm |
| 300 | 13° | 1 dB | 0.025 s | 3.3 mm |

$K_p=60$ deja 15 dB y 75°, y el tramo lineal ya no domina el $t_s$. Más allá de ≈ 150 el margen se degrada por la resonancia sin ganar nada en $t_s$.

### Ki = 1

- $T_i=K_p/K_i=60$ s: el cero del PI está en 0.017 rad/s, unas 1900 veces por debajo del cruce (≈ 32 rad/s). No cambia el margen de fase ni el sobrepaso.
- Su función es llevar a cero el error ante perturbaciones constantes (carga, sesgo de la válvula, fugas) y ante rampas. Es lenta: constante de tiempo de decenas de segundos, mayor que los 4 s simulados.
- El anti-windup por *clamping* evita acumular integral durante los ≈ 0.75 s de saturación; sin él habría más sobrepaso.

### Sobrepaso medido (Mp = 3.43 %, 13.7 mm)

El pistón entra en la banda lineal (16.7 mm) a velocidad máxima y frena con $\tau\approx31$ ms. Un primer orden puro no sobrepasaría; el 3.4 % viene de la dinámica que el modelo simple no incluye (válvula y resonancia con $\zeta_h$ bajo). Cumple Mp < 10 %.

### Muestreo

$T_s=10$ ms ≪ $t_s$ (1.05 s). La resonancia hidráulica (≥ 62 Hz) queda por encima de Nyquist (50 Hz); si se excitara, aparecería como alias. No se espera excitarla porque la válvula opera saturada casi todo el recorrido y el frenado es suave.

## 7. Supuestos y puntos abiertos

- **Linealización:** zona lineal sin saturación, $\dot x_0=0$, volúmenes ≈ $V_{A0}$, $V_{B0}$, fricción viscosa. Con saturación manda el comportamiento no lineal (sección 6, $t_s$).
- **$K_v$ estimado** con el caudal nominal sobre el área del pistón. El caudal real depende de la caída de presión en la válvula.
- **$\omega_h$:** este documento da ≈ 548 rad/s con los volúmenes de `MARLUP_hydr_params.m`; el informe (`informe_pil.tex`) dice ≈ 390 rad/s. Hay que decidir cuál es la correcta (¿se incluyó el volumen de las tuberías?). Afecta el alias estimado.
- **Ganancias en el modelo de 3 pistones:** `MODELOS/CINEMATICA/pil_ctrl3.m` usa Kp = 6.7, Ki = 1, Usat = 0.1 (nivelación de la mesa), no 60/1/1.
- Los márgenes de la tabla son un cálculo analítico con el modelo lineal; no se validaron con una simulación en MATLAB.
