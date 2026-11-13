# Bitácora de experimentos: plataforma completa (3 pistones)

Planes y resultados de los experimentos con `Model_aaron.slx` (MiL) y `Model_aaronC.slx` (PiL).
Más reciente primero. El historial general del PiL está en la *Bitácora* del `README.md` de la raíz.

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
