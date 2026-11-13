# Bitácora de experimentos: plataforma completa (3 pistones)

Planes y resultados de los experimentos con `Model_aaron.slx` (MiL) y `Model_aaronC.slx` (PiL).
Más reciente primero. El historial general del PiL está en la *Bitácora* del `README.md` de la raíz.

## 13 nov 2026: plan del experimento 1, barrido de la ganancia de nivelación K (por ejecutar)

**Objetivo.** Explicar por qué el lazo de nivelación atenúa -13 dB y no los -26 dB que predice
1/(1+K) con K = 20, y producir las gráficas del PiL. **Hipótesis:** el lazo interno de cada
cilindro (polo cerca de -3.55 rad/s con Kp = 6.7) no sigue bien la referencia, y eso limita la
ganancia efectiva del lazo exterior. Si es así, la atenuación deja de mejorar a partir de cierto
K, o aparecen saturación de las válvulas u oscilación. Con un lazo interno más rápido (las
ganancias rediseñadas) la curva debería acercarse a la predicha.

**Criterio de desempeño** (reemplaza al de 0.20°, que depende del recorte del oleaje):
atenuación del RMS de pitch y roll ≥ **12 dB** respecto al caso sin compensar (K = 0). El umbral
es una propuesta: Aarón lo confirma antes de correr y no se cambia después de ver los resultados.

**Antes de correr:**
1. Pedir a la compañera las ganancias rediseñadas (`Kp`, `Ki` y, si cambia, `Usat`), con la
   función de transferencia y el criterio con que las obtuvo. Anotarlas en la tabla de abajo.
   Sin ellas solo se corre el controlador A.
2. Agregar a `correr_pil3` el registro del comando de las tres válvulas (salida de
   `Controlador`), para calcular `u_RMS` y el porcentaje del tiempo en saturación (|u| ≥ Usat).
   Hoy solo registra roll y pitch.
3. Escribir `MODELOS/CINEMATICA/exp_barrido_k.m`, que llame a `correr_pil3(..., 'Figura', false)`
   en un solo MATLAB y guarde todo en `DOCS/AVANCES/AVANCE 3/resultados/exp1_barrido_k.mat` y
   `exp1_barrido_k.csv`. Debe guardar después de cada corrida para no perder lo hecho si algo
   falla.

**Controladores comparados** (lazo interno):

| Id | Kp | Ki | Usat | Origen |
|---|---|---|---|---|
| A | 6.7 | 1 | 1 | Actual (`config_pil3.m`) |
| B | _pendiente_ | _pendiente_ | _pendiente_ | Rediseño a partir de la función de transferencia |

**Diseño.** Siempre los mismos factores fijos: Hs = 0.5 m, Tp = 10 s, `rng(42)`, Tsim = 30 s,
TIni = 2 s y sensor ideal (`NoIdeal = [0 0 0]`).

| Fase | Modo | Corridas | Cuántas |
|---|---|---|---|
| 1 | MiL | K ∈ {0, 2, 5, 10, 20, 40, 80} con el controlador A | 7 |
| 2 | MiL | Los mismos K con el controlador B | 7 |
| 3 | PiL | Con el mejor controlador: K = 0, el K elegido y el mayor K estable | 3 |

- Un barrido se corta al primer K **inestable**: la simulación falla o el pico supera al de
  K = 0. Esa K y el último estable se anotan.
- El **K elegido** es el menor que cumple el criterio con margen (≥ 3 dB sobre el umbral) sin
  pasar del 5 % del tiempo en saturación.
- El PiL solo confirma: si el PiL ideal coincide con el MiL (RMSE < 0.001°), los barridos en MiL
  valen para el PiL.

**Métricas por corrida:** pico y RMS de pitch y roll (°), atenuación del RMS contra K = 0 (dB),
`u_RMS` y porcentaje del tiempo en saturación de cada válvula, y tiempo de simulación. En el PiL,
además, RMSE y error máximo contra el MiL con el mismo K.

**Gráficas** (`DOCS/AVANCES/AVANCE 3/figuras/fig_barrido_k.m`):
1. Atenuación medida contra K (escala logarítmica), una curva por controlador, junto con la
   predicha 20·log10(1/(1+K)) y el umbral de 12 dB. La separación entre medida y predicha es lo
   que hay que explicar.
2. `u_RMS` y porcentaje del tiempo en saturación contra K.
3. Pitch de la mesa en el tiempo de las tres corridas PiL, superpuesto al MiL.

**Duración estimada.** Según las corridas del 13 nov en esta computadora, un MiL de 30 s tarda
110–117 s y un PiL 146–194 s, recompilación incluida.

| Fase | Cálculo | Tiempo |
|---|---|---|
| 1 y 2 | 14 MiL × ~2 min | ~28 min |
| 3 | 3 PiL × ~3 min + compilación y carga al Arduino | ~10–12 min |
| Arranque de MATLAB, carga de modelos y figuras | | ~5 min |
| **Total** | | **~45 min** (hasta ~1 h 15 min si los K altos vuelven rígido el solver) |

Con K grande el solver de paso variable puede tomar pasos muy pequeños: si una corrida pasa de
10 min, se detiene y esa K se anota como inestable. Las corridas van **de una en una**: la RAM
(7.4 GB) no alcanza para dos MATLAB en paralelo; cerrar VS Code y no abrir Mechanics Explorer.

**Al terminar:** registrar aquí los resultados (tabla y conclusión sobre la hipótesis) y llevar
la figura 1 y la tabla al informe del Avance 3, en lugar del `\pendiente` que pide "confirmarla
con una corrida en que se varíe K".
