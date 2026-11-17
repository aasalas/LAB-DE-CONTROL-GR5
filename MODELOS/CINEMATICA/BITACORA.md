# Bitácora de experimentos: plataforma completa (3 pistones)

Planes y resultados de los experimentos con `Model_aaron.slx` (MiL) y `Model_aaronC.slx` (PiL).
Más reciente primero. El historial general del PiL está en la *Bitácora* del `README.md` de la raíz.

## 16 nov 2026 (madrugada): arquitectura B y optimización de Kp, Ki y presión (`exp11`)

**Decisión de Aarón:** quedarse con la **arquitectura B**, prealimentación pura: IMU de la base →
cinemática inversa → 3 PI, sin lazo K sobre la mesa, sin saturación ni prealimentación de velocidad en
los pistones. Es el esquema de Wang et al. (2025). Acepta un error mayor a cambio de la simplicidad.

**B contra la arquitectura anterior (MiL, 30 s, Kp = 20, Ki = 1, 160 bar):**

| Caso | Pico pitch | Pico roll |
|---|---|---|
| B, nominal (Hs = 2 m, Tp = 10 s) | 0.449° | 0.200° |
| B, base de 15° (Hs = 15.49 m, Tp = 12 s) | 2.283° | 1.044° |
| Anterior (Kff = 1 + K = 3, ±30°), 15° | 0.66° | 0.30° |

- La cinemática actual ya es la **inversa exacta** de la base: la unión `Unión 4DOF` aplica Rx y luego Ry,
  y `marlup_ik` lo deshace en ese orden. Invertir el orden dio 2.290° (igual o peor).
- El residuo de B es el **atraso de los pistones**, no la geometría: el pistón 1 se atrasa hasta 28.3 mm
  (11.1 y 16.6 mm los otros), y 28 mm / 0.694 m/rad ≈ 2.3°. La media del error es ~0 (sin deriva).
- La saturación de ±30° nunca actuaba: sin ella los pistones van de 0.015 a 0.397 m (carrera 0–0.45 m).

**Optimización (`exp11_opt_prealimentacion.m`, ~20 min la primera vez; el barrido solo, 30 s).**
Palancas fieles a la prealimentación pura: Kp, Ki y presión de suministro (160 a 500 bar; el CDH1 es de
**250 bar nominales**, 375 de prueba). Método: un sustituto del pistón (PI discreto + curva v(u)
identificada por presión + τ + θ) barre 1512 combinaciones en 30 s. Calibra con 2 % de error contra la
plataforma en el seguimiento de los pistones, pero **no predice el sobrepaso** del escalón de 10 mm del
modelo no lineal (16 puntos de error medio). Por eso la regla de `diseno_pi` (Mp ≤ 10 %, ts ≤ 2 s,
MG ≥ 10 dB, MF ≥ 60°) se aplica con una búsqueda de frontera (bisección del mayor Kp por presión y Ki)
en el modelo no lineal de un pistón.

| Validado en la plataforma (B) | 15°: pitch / roll | Nominal: pitch / roll | Mp 10 mm |
|---|---|---|---|
| Actual: 20/1, 160 bar | 2.283° / 1.044° | 0.449° / 0.200° | 2.4 % |
| **27.5/1, 160 bar** (solo cambia Kp) | **1.793° / 0.868°** | **0.349° / 0.161°** | 7.5 % |
| 22.5/1, 250 bar | 1.657° / 0.831° | 0.334° / 0.157° | 9.3 % |
| 12.5/16, 500 bar (fuera de norma) | 1.691° / 0.626° | — | 9.5 % |

- **La restricción activa es el sobrepaso del escalón de 10 mm.** Más presión sube la ganancia de la
  válvula (Kv 0.74 → 1.31 m/s de 160 a 500 bar), pero obliga a bajar Kp en la misma proporción, así que
  la ganancia del lazo queda casi igual: de 160 a 250 bar el pitch a 15° solo baja 8 % (1.79° → 1.66°).
- **Ki alto (32–48) bajaría el residuo a ~1°**, porque el integrador sigue mejor la rampa de la ola, pero
  sobrepasa 13–28 % en el escalón de 10 mm del modelo no lineal: no cumple la regla.
- **Mejor opción realista: Kp = 27.5, Ki = 1 a 160 bar**: −21 % a 15° y −22 % en el nominal, sin
  cambiar el equipo. El predictor del sustituto subestima el pitch final ~5 % (1.70° contra 1.79°).
- 500 bar deja los pistones a 6 mm del tope (0.006 m) y da peor pitch que 250 bar: descartado.

Resultados: `DOCS/AVANCES/AVANCE 3/resultados/exp11_*.mat/.csv`, figura `figuras/exp11_barrido.png`.
**Pendiente de decisión de Aarón:** adoptar Kp = 27.5 (hoy el controlador único es Kp = 20, Ki = 1) e
implementar B en `Model_aaron.slx` y `Model_aaronC.slx`.

## 16 nov 2026 (noche): prealimentación de la base, controlador final

**Decisión de Aarón:** volver a su esquema original (Fig. 3 del informe): la mesa recibe el ángulo
contrario al de la base, medido por un IMU en la base. Con g = 0.188 no podía funcionar; con g = 1 sí.
Ley final: `θ_c = sat±0.3(−Kff·θ_b + K·(0 − θ))`, con **Kff = 1, K = 3**, Kp = 20, Ki = 1. Un ajuste
con K = 0 confirma que la mesa reproduce la base con ganancia 1.02 (roll) y 0.99 (pitch).

Hs = 2 m, Tp = 10 s (`exp5_prealimentacion.m`, `exp6_final_ff.m`, `fig_final.m`):

| Caso | Pico pitch (°) | RMS pitch (°) | Pico roll (°) | Aten. pitch (dB) |
|---|---|---|---|---|
| Sin compensar | 2.878 | 1.434 | 1.522 | 0 |
| Solo realimentación, K = 3 | 0.735 | 0.362 | 0.383 | −12.0 |
| Final, MiL = PiL ideal | 0.128 | 0.054 | 0.060 | −28.4 |
| Final, PiL no ideal (5 LSB) | 0.250 | 0.066 | 0.186 | −26.7 |

Oleajes agresivos (MiL salvo indicación; `fig_oleaje.m`):

| Tp (s) | Base | Solo realim. | Final MiL | Final PiL no ideal | Sat. válvulas (final) |
|---|---|---|---|---|---|
| 7.5 | 5.1° | 1.34° | 0.32° | 0.59° (roll 0.81°) | 0 % |
| 5.3 | 10.1° | 23.9° | 28.6° | Simscape se detiene en t = 12.7 s | 48 % |
| 4.3 | 15.2° | 35.2° | 23.7° | Simscape se detiene en t = 11.3 s | 72 % |

**Límite físico, no de control:** seguir la base exige mover los cilindros a 0.06 / 0.13 / 0.38 / 0.70 m/s
(bases de 3 / 5 / 10 / 15°), con elongaciones de hasta 39 / 70 / 139 / 207 mm. A válvula abierta
llegan a 0.43 m/s extendiendo y 0.29 m/s retrayendo. Para 10° y 15° haría falta más caudal.

## 16 nov 2026 (tarde): cinemática inversa corregida, g = 1, K = 3

**Decisión de Aarón:** el objetivo es g = 1. Se corrigió `marlup_ik` en ambos modelos:
`d = R*(pP + [0; 0; z]) - b` (T = Ry·Rx·Trasl(0,0,z), la mesa gira sobre el centro de la base).
Medido con un escalón de 1° y mar plano sobre el modelo guardado: **g_roll = 1.007, g_pitch = 1.003**
(antes 0.191 y 0.188). La saturación del comando de ángulo bajó de ±0.6 a **±0.3 rad** (17° reales,
dentro de la carrera de ±220 mm).

Barrido de K con g = 1 (`exp4_k_ik.m`, MiL, Hs = 2 m, Tp = 10 s):

| K | 0 | 2.8 | 4 | 6 | 9 | 15 |
|---|---|---|---|---|---|---|
| Pico pitch (°) | 2.88 | 0.77 | 0.59 | 21.4 (inestable) | 28.1 (inestable) | 28.2 (inestable) |
| Atenuación pitch (dB) | 0 | −11.5 | −13.9 | — | — | — |

K = 2.8 reproduce el resultado anterior (K = 15 con g = 0.188): el modelo es consistente. El límite de
estabilidad del lazo exterior está entre K = 4 y 6 y no depende de la cinemática. Con g = 1, K = 15
es inestable, así que **se fijó K = 3** (margen de 2× hasta K = 6; Kp = 20 y Ki = 1 sin cambios).

| Caso K = 3 (Hs = 2 m, Tp = 10 s) | Pico pitch (°) | RMS pitch (°) | Pico roll (°) | RMS roll (°) |
|---|---|---|---|---|
| MiL | 0.735 | 0.362 | 0.383 | 0.140 |
| PiL no ideal (5 LSB) | 0.786 | 0.358 | 0.512 | 0.148 |

**Pendiente:** rehacer `exp2_final` y `exp3_oleaje` con K = 3 y actualizar el informe del Avance 3,
que todavía describe la cinemática anterior (K = 15, g = 0.188).

## 16 nov 2026: encoder en la realimentación, ruido de 5 LSB, oleajes de 5°, 10° y 15° y causa de g

**Encoder lineal.** Las no idealidades ya actuaban sobre la medición (el error se calcula dentro de
`ctrl_pi3`), pero estaban en `Interfaz sensor`, junto al camino de la referencia. Pasaron a un
subsistema **`Linear encoder`** entre cada pistón y la interfaz, que ahora se llama **`Interfaz MCU`**
(solo ZOH a 10 ms y `single`). El MiL ideal reproduce el escenario final (pitch 0.784°). El ruido
subió de 1 a **5 LSB (σ = 2.2 mm)**, porque con 1 LSB la diferencia en la mesa era de 0.0075° RMS.

Escenario final con el ruido nuevo (Hs = 2 m, Tp = 10 s, K = 15; `fig_final.m`):

| Caso | Pico pitch (°) | RMS pitch (°) | Pico roll (°) | RMS roll (°) | u_RMS máx |
|---|---|---|---|---|---|
| PiL ideal (= MiL) | 0.784 | 0.382 | 0.418 | 0.149 | 0.032 |
| PiL no ideal (5 LSB) | 0.823 | 0.376 | 0.534 | 0.154 | 0.066 |

PiL no ideal − PiL ideal: 0.042° RMS (0.145° máx) en pitch y 0.041° RMS (0.157° máx) en roll.
Ruido en el comando de las válvulas: 0.058 RMS (0.24 máx), ≈ Kp·σ = 0.044 más la cuantización.

**Oleajes más agresivos (`exp3_oleaje.m`, `fig_oleaje.m`).** La pendiente crece como Hs/Tp². Con
Hs = 2 m y la función del bloque P-M evaluada fuera de Simulink se eligieron Tp = 7.5, 5.3 y 4.3 s
(picos de 5.1°, 10.1° y 15.2° en la base). Tp configurable en `correr_pil3(..., 'Tp', x)`.

| Tp (s) | Sin compensar | MiL K = 15 | PiL no ideal K = 15 | Válvulas saturadas |
|---|---|---|---|---|
| 7.5 | 5.11° | 1.46° | 1.47° | 0 % |
| 5.3 | 10.14° | 16.63° | 15.13° | 11–12 % |
| 4.3 | 15.15° | 19.97° | 24.58° | 18–29 % |

Con 5° la atenuación es la de siempre (−11.2 dB) pero no se cumple 1°. Con 10° y 15° el lazo pierde
la nivelación: el comando de ángulo se satura en ±0.6 rad (= 6.5° reales con g = 0.188) y las
válvulas saturan. El controlador cumple hasta ~3.7° de base.

**Causa de g (análisis de Fable sobre el XML del ensamble, sin simulación).** La unión superior de cada
pata es un único pasador tangencial (`Garra i/Rigid Transform3` suelda la cruceta), así que la mesa
gira alrededor del centro de la base y no de su centro, como supone `marlup_ik`:
**g = R_TOP/R_BASE = 0.143/0.7608 = 0.188**. Predice la atenuación medida para K = 5…20 con error
< 0.2 dB, el 18 % del Avance 2 y el Bias de pitch del sensor. Corrección posible en `marlup_ik`:
`d = R*(pP + [0; 0; z]) - b` (g ≈ 1), pero con K = 15 la ganancia de lazo pasaría de 2.8 a 15
(inestable según K = 30): exigiría K ≈ 2.8 y saturación ≈ ±0.3 rad. **Pendiente de decisión de Aarón.**

## 13 nov 2026: controlador único, requisito de 1° y escenario final (cerrado)

**Decisiones de Aarón:** un solo controlador de aquí en adelante, en todo el proyecto
(`ctrl_pi.slx`, `ctrl_pi3.slx`, `config_pil3.m`): **Kp = 20, Ki = 1, K = 15**. El requisito pasa
de 0.2° a **1°**, con una perturbación considerable (**Hs = 2 m**). En la sección de diseño del
informe aparece solo el controlador final. La etapa 2 del experimento 1 (factorial con el
controlador de la compañera) no se hizo: su análisis justificaba Kp = 6.7, pero no identificaba
la planta ni medía la respuesta al escalón.

### Diseño del PI (`MODELOS/PISTON/diseno_pi.m`, ~3 min, sin Arduino)

1. **Función de transferencia.** La linealización automática de Simulink (`linearize`) dio una
   planta distinta en cada intento, una inestable, así que se identificó con escalones en lazo
   abierto sobre el modelo no lineal en x0 = 0.23 m (u = ±0.02, ±0.05, ±0.1, ±1):
   G(s) = 0.636·e^(−0.0088 s) / (s·(0.0085 s + 1)). Kv = 0.740 m/s extendiendo y 0.532 m/s
   retrayendo; a válvula abierta, 0.43 y 0.29 m/s. **El modelo no muestra la resonancia
   hidráulica** (ωh ≈ 420–548 rad/s) en la que se basaba el análisis anterior.
2. **14 candidatos:** los PI en uso (6.7/1, 60/1, 20/1), `pidtune` con MF de 60° y 75° y cruces
   de 5 a 30 rad/s, y Ziegler–Nichols.
3. **Regla, fijada antes de correr:** Mp ≤ 10 %, ts ≤ 2 s, |e_ss| < 2.3 mm, MG ≥ 10 dB y
   MF ≥ 60°, con G(s) y con el modelo no lineal en dos escalones (10 mm en x0 y 0 → 0.40 m).
   Gana el de menor ts en el escalón de 10 mm; si empatan, el de menor Mp.
4. **Resultado:** cumplen tres (20/1, 23.8/6.26 y 15.8/2.77); gana **Kp = 20, Ki = 1**: Mp 2.4 %,
   ts 0.28 s en el escalón pequeño; Mp 0.1 %, ts 0.96 s en el grande; MG 16.9 dB y MF 73.7°.
   Kp = 6.7 no entra en la banda del 2 % en el escalón pequeño; Kp = 60 sobrepasa 61 %;
   Ziegler–Nichols, 180 %.
5. **Validación unitaria con ese PI en el Arduino** (`run_pil`): Mp 0.13 %, ts 0.96 s,
   e_ss 0.20 mm; PiL ideal idéntico al MiL, PiL no ideal a 0.16 mm RMS del MiL.

### Barrido de K con el PI nuevo y Hs = 0.5 m (archivado en `resultados/previos/`)

| K | 0 | 5 | 10 | 15 | 20 | 30 |
|---|---|---|---|---|---|---|
| Pico pitch (°) | 0.717 | 0.372 | 0.252 | 0.190 | 0.178 | 2.56 (inestable) |
| Atenuación pitch (dB) | 0 | −5.7 | −9.2 | −11.6 | −13.4 | — |

PiL en el Arduino con K = 0, 15 y 20: idéntico al MiL. Se eligió **K = 15**.

### Hallazgo: la saturación del lazo exterior limitaba la nivelación

Con Hs = 2 m el pitch no bajaba de 1° y **empeoraba al subir K** (K = 5: 1.88°; K = 20: 2.35°).
Causa: el comando de ángulo estaba saturado a ±0.1 rad y la mesa solo realiza el 18 % del ángulo
ordenado (g ≈ 0.184, sin explicar), así que el lazo podía compensar a lo sumo 0.1·g ≈ 1°. Con la
saturación en **±0.6 rad** (unos 80 mm de elongación, dentro de la carrera libre de ±220 mm)
el pitch con K = 15 bajó de 2.23° a 0.78°. Se cambió en los dos modelos.

### No idealidades: por qué no se notaban y qué se hizo

El sesgo es igual en los tres pistones (solo sube la mesa, no la inclina), el lazo exterior mide
el ángulo de la mesa sin error y corrige los errores de posición, y las magnitudes (0.44 mm del
ADC) equivalen a centésimas de grado. Se agregó **ruido eléctrico de σ = 0.44 mm (1 LSB),
independiente en cada pistón**, antes del ADC (`en_ruido`, `ruido_mm` en `config_pil3.m`;
`NoIdeal = [lin hist q ruido]` en `correr_pil3`).

### Escenario final (`exp2_final.m`, ~16 min; figuras con `fig_final.m`)

Hs = 2 m, Tp = 10 s, 30 s, Kp = 20, Ki = 1, Usat = 1, saturación ±0.6 rad.

| Caso | Pico pitch (°) | RMS pitch (°) | Pico roll (°) | RMS roll (°) | Aten. (dB) | u_RMS máx |
|---|---|---|---|---|---|---|
| Sin compensar (K = 0) | 2.878 | 1.434 | 1.522 | 0.561 | 0 | 0.0013 |
| MiL, K = 5 | 1.511 | 0.746 | 0.798 | 0.290 | −5.7 | 0.022 |
| MiL, K = 10 | 1.028 | 0.504 | 0.549 | 0.198 | −9.1 | 0.029 |
| **MiL, K = 15** | **0.784** | 0.382 | 0.418 | 0.149 | −11.5 | 0.032 |
| MiL, K = 20 | 0.636 | 0.306 | 0.352 | 0.119 | −13.4 | 0.035 |
| PiL ideal, K = 15 | 0.784 | 0.382 | 0.418 | 0.149 | −11.5 | 0.032 |
| PiL no ideal, K = 15 | 0.783 | 0.379 | 0.426 | 0.150 | −11.6 | 0.034 |

- K mínimo para 1°: (2.88/1 − 1)/0.184 = **10.2**; K = 15 deja 22 % de margen.
- PiL ideal = MiL (RMSE 0). PiL no ideal − PiL ideal: 0.0075° RMS (0.033° máx) en pitch.
- El ruido sí se ve en el **comando de las válvulas**: 0.012 RMS (0.05 máx), ≈ Kp·σ = 0.009 más
  la cuantización (`figuras/pil_comando.png`).

**Pendientes:** explicar g = 0.184; confirmar con Mónica y Eduardo el recorte direccional del
bloque P-M (por él se usa Hs = 2 m); tiempo de ejecución en el ATmega328P y latencia del PiL.

## 13 nov 2026: experimento 1, ganancia de nivelación y lazo interno (histórico)

Se hizo antes de fijar el controlador único. Datos y scripts archivados en
`DOCS/AVANCES/AVANCE 3/resultados/previos/` (ver su `LEEME.md`); ya no reproducen estos números
porque el modelo cambió después. Condiciones: Hs = 0.5 m, Tp = 10 s, 30 s, saturación del lazo
exterior ±0.1 rad, sensor ideal, Ki = 1.

**Pregunta.** Por qué el lazo de nivelación atenuaba −13 dB y no los −26 dB que predice 1/(1+K)
con K = 20. **Hipótesis:** el lazo interno (Kp = 6.7) es lento y limita la ganancia efectiva.

**Plan original, en tres etapas:** (1) factorial 2³ de K, Kp y Usat con el controlador de
entonces; (2) el mismo factorial con el controlador rediseñado por la compañera; (3) barrido de K
y PiL con el controlador final. La etapa 2 se descartó: el PI se rediseñó con
`MODELOS/PISTON/diseno_pi.m` (entrada de arriba) y con él se corrió directamente la etapa 3.

### Etapa 1: factorial 2³ en MiL (10 corridas, ~13 min)

| # | K | Kp | Usat | Pico pitch (°) | RMS pitch (°) | Atenuación (dB) | u_RMS máx | % saturada | Estable |
|---|---|---|---|---|---|---|---|---|---|
| 0 | 0 | 6.7 | 1 | 0.717 | 0.367 | 0 | 0.0013 | 0 | sí |
| 1 | 5 | 3 | 0.1 | 0.437 | 0.213 | −4.7 | 0.0051 | 0 | sí |
| 2 | 40 | 3 | 0.1 | 0.110 | 0.050 | −17.4 | 0.0097 | 0 | sí |
| 3 | 5 | 20 | 0.1 | 0.372 | 0.190 | −5.7 | 0.0053 | 0 | sí |
| 4 | 40 | 20 | 0.1 | 0.253 | 0.106 | −10.8 | 0.091 | 75 | sí, saturada |
| 5 | 5 | 3 | 1 | 0.437 | 0.213 | −4.7 | 0.0051 | 0 | sí |
| 6 | 40 | 3 | 1 | 0.110 | 0.050 | −17.4 | 0.0097 | 0 | sí |
| 7 | 5 | 20 | 1 | 0.372 | 0.190 | −5.7 | 0.0053 | 0 | sí |
| 8 | 40 | 20 | 1 | 2.757 | 0.815 | +6.9 | 0.187 | 0 | **no** |
| C | 14 | 8 | 0.3 | 0.207 | 0.104 | −11.0 | 0.0078 | 0 | sí |

**Conclusiones de la etapa 1:**
- **La hipótesis no se sostuvo.** Subir Kp de 3 a 20 casi no mejora la atenuación (−4.7 contra
  −5.7 dB con K = 5). El lazo interno no era el límite.
- **La atenuación la fija K, con una ganancia efectiva menor:** todas las corridas estables siguen
  1/(1 + g·K) con g ≈ 0.15–0.19. Esa es la explicación de los −13 dB: 1/(1 + 0.18·20) = 0.22.
  El origen de g < 1 sigue pendiente.
- **Usat no influye** mientras el comando no llegue al límite (parejas 1/5, 2/6 y 3/7
  idénticas): el u_RMS normal es de ~0.005.
- **El producto K·Kp limita la estabilidad:** K = 40 con Kp = 20 es inestable (corrida 8), y con
  Usat = 0.1 queda en un ciclo límite saturado el 75 % del tiempo (corrida 4).
- El RMS de pitch con K = 0 dio 0.367° y no los 0.335° anotados antes en el README. La diferencia
  no se aclaró (el pico, 0.717°, coincide); el dato vigente es el de estas corridas.

### Etapa 3: barrido de K y PiL con Kp = 20, Ki = 1

Resultados en la entrada de arriba (*Barrido de K con el PI nuevo y Hs = 0.5 m*).

### Tiempos medidos en esta computadora (7.4 GB de RAM)

MiL de 30 s: 60–110 s por corrida. PiL: 105–225 s, y cada cambio de Kp, Ki o Usat recompila y
carga el programa al Arduino. Las corridas van de una en una; cerrar VS Code y no abrir Mechanics
Explorer.
