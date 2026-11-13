# Bitácora de experimentos: plataforma completa (3 pistones)

Planes y resultados de los experimentos con `Model_aaron.slx` (MiL) y `Model_aaronC.slx` (PiL).
Más reciente primero. El historial general del PiL está en la *Bitácora* del `README.md` de la raíz.

## 13 nov 2026: plan del experimento 1, ganancia de nivelación y lazo interno (por ejecutar)

**Objetivo.** Explicar por qué el lazo de nivelación atenúa -13 dB y no los -26 dB que predice
1/(1+K) con K = 20, y producir las gráficas finales del PiL.

**Hipótesis.** El lazo interno de cada cilindro (polo cerca de -3.55 rad/s con Kp = 6.7) no sigue
bien la referencia, y eso limita la ganancia efectiva del lazo exterior. Si es así, deberían verse
tres cosas:
- el efecto de K sobre la atenuación es mayor cuando el lazo interno es rápido (interacción K × Kp);
- la atenuación deja de mejorar a partir de cierto K;
- al limitar el comando de la válvula (Usat bajo), la atenuación empeora.

**Criterio de desempeño.** Reemplaza al de 0.20°, que depende del recorte del oleaje: la
atenuación del RMS de pitch y de roll debe ser de al menos **12 dB** respecto al caso sin
compensar (K = 0). El umbral es una propuesta: Aarón lo confirma antes de correr y no se cambia
después de ver los resultados.

**Reparto del trabajo.** Sonnet escribe los scripts y ejecuta las corridas. Opus analiza los
resultados de cada etapa, los documenta en esta bitácora y define los niveles de la etapa
siguiente. Los **resultados finales** (informe y gráficas) salen solo del controlador PI
rediseñado por la compañera (controlador B). El controlador actual (A) se usa únicamente en la
etapa 1, para entender el sistema mientras llegan sus ganancias.

**Controladores (lazo interno):**

| Id | Kp | Ki | Usat | Origen |
|---|---|---|---|---|
| A | 6.7 | 1 | 1 | Actual (`config_pil3.m`); solo para la etapa 1 |
| B | _pendiente_ | _pendiente_ | _pendiente_ | Rediseño de la compañera a partir de la función de transferencia |

**Factores fijos en todas las corridas:** Hs = 0.5 m, Tp = 10 s, semilla `rng(42)`, Tsim = 30 s,
TIni = 2 s y sensor ideal (`NoIdeal = [0 0 0]`). Ki = 1, salvo que el controlador B diga otra cosa.

### Preparación (antes de la etapa 1)

1. Agregar a `correr_pil3` el registro del comando de las tres válvulas (salida de `Controlador`).
   Con eso se calculan `u_RMS` y el porcentaje del tiempo en saturación (|u| ≥ Usat). Hoy solo
   registra roll y pitch.
2. Escribir `MODELOS/CINEMATICA/exp_corridas.m`. Recibe una tabla de corridas (modo, K, Kp, Ki,
   Usat) y llama a `correr_pil3(..., 'Figura', false)` en un solo MATLAB. Guarda las métricas
   en `DOCS/AVANCES/AVANCE 3/resultados/exp1_<etapa>.mat` y `.csv` **después de cada corrida**,
   para no perder lo hecho si algo falla. Así las tres etapas usan el mismo script.
3. Con K grande, o con Kp alto y Usat bajo, el solver de paso variable puede tomar pasos muy
   pequeños. Si una corrida pasa de 10 min, se detiene y se anota como **inestable**. Una corrida
   también es inestable si la simulación falla o si el pico supera al de K = 0.
4. Las corridas van **de una en una**, porque la RAM (7.4 GB) no alcanza para dos MATLAB en
   paralelo. Cerrar VS Code y no abrir Mechanics Explorer.

### Etapa 1: factorial 2³ con el controlador A (ahora)

Tres factores con un nivel bajo (−) y uno alto (+). El nivel central es la media geométrica de los
extremos.

| Factor | − | Centro | + | Qué prueba |
|---|---|---|---|---|
| A: K (lazo de nivelación) | 5 | 14 | 40 | Cuánto mejora la atenuación al subir K |
| B: Kp (lazo interno) | 3 | 8 | 20 | Si la rapidez del lazo interno limita la atenuación (la hipótesis) |
| C: Usat (comando máximo de la válvula) | 0.1 | 0.3 | 1 | Si la saturación limita la atenuación. Mónica usaba 0.1 |

El margen de ganancia estimado del lazo interno con Kp = 20 es de ~4.8 (2ζhωh/(Kp·Kv)), de modo
que debería ser estable. Si no lo es, ese resultado también se anota.

| # | K | Kp | Usat |
|---|---|---|---|
| 1 | 5 | 3 | 0.1 |
| 2 | 40 | 3 | 0.1 |
| 3 | 5 | 20 | 0.1 |
| 4 | 40 | 20 | 0.1 |
| 5 | 5 | 3 | 1 |
| 6 | 40 | 3 | 1 |
| 7 | 5 | 20 | 1 |
| 8 | 40 | 20 | 1 |
| C | 14 | 8 | 0.3 |
| 0 | 0 | 6.7 | 1 |

- Las corridas 1–8 son el factorial en orden estándar. **C** es el punto central y **0** el caso
  sin compensar, que es la referencia de la atenuación. Todo se corre en MiL.
- La simulación es determinista (misma semilla), así que no hay réplicas ni hace falta aleatorizar
  el orden. Para no recompilar, conviene agrupar las corridas por Kp.
- **Respuesta principal:** atenuación del RMS de pitch, en dB. **Secundarias:** atenuación de roll,
  `u_RMS` máximo de las tres válvulas y porcentaje del tiempo en saturación.
- **Análisis (Opus).** Con los niveles codificados ±1, cada efecto es la media de la respuesta en
  + menos la media en −. Hay 7 efectos: A, B, C, AB, AC, BC y ABC.
  - Gráfica de Pareto de los efectos.
  - Gráfica de interacción K × Kp, que es la prueba directa de la hipótesis.
  - Curvatura: la respuesta del centro menos la media de las 8 esquinas. Si es grande, el
    modelo lineal en los factores no basta y la etapa 3 (barrido) es necesaria.
- **PiL de confirmación:** se repiten en PiL la mejor y la peor esquina (2 corridas). Esto verifica
  que la conclusión vale también en el Arduino, sobre todo con Usat = 0.1, donde el redondeo en
  `single` podría pesar más.

### Etapa 2: el mismo factorial con el controlador B (cuando lleguen las ganancias)

- Kp y Ki pasan a ser los del controlador B. El factorial queda en 2² (K × Usat) más el punto
  central y K = 0: 6 corridas MiL.
- Los niveles de K y de Usat los fija Opus a partir de la etapa 1. Por ejemplo, si K = 40 ya
  satura, se baja el nivel alto. Los niveles quedan escritos aquí antes de correr.
- Se comparan los efectos con los de la etapa 1. Si el controlador B es más rápido, el efecto de K
  debería crecer.
- 1 corrida PiL de confirmación con la mejor combinación.

### Etapa 3: resultados finales, solo con el controlador B

- Barrido de K en MiL: K = 0 más 6 valores entre el nivel bajo y el alto de la etapa 2, en escala
  logarítmica (por ejemplo {0, 2, 5, 10, 20, 40, 80}), con el Usat elegido. Se corta al primer K
  inestable.
- **K elegido:** el menor que cumple el criterio con margen (≥ 3 dB sobre el umbral) sin pasar del
  5 % del tiempo en saturación.
- PiL: K = 0, el K elegido y el mayor K estable. Si el PiL ideal coincide con el MiL
  (RMSE < 0.001°), el barrido en MiL vale para el PiL.
- **Gráficas** (`DOCS/AVANCES/AVANCE 3/figuras/fig_barrido_k.m`):
  1. Atenuación medida contra K (escala logarítmica), junto con la predicha 20·log10(1/(1+K)) y el
     umbral de 12 dB.
  2. `u_RMS` y porcentaje del tiempo en saturación contra K.
  3. Pitch de la mesa en el tiempo de las tres corridas PiL, superpuesto al MiL.

  La gráfica de interacción de las etapas 1 y 2 puede ir en el informe como justificación del
  diseño, aclarando que la etapa 1 usa el controlador anterior.

### Métricas por corrida

Pico y RMS de pitch y roll (°), atenuación del RMS contra K = 0 (dB), `u_RMS` y porcentaje del
tiempo en saturación de cada válvula, y tiempo de simulación. En el PiL, además, el RMSE y el
error máximo contra el MiL con los mismos parámetros.

### Duración estimada

Según las corridas del 13 nov en esta computadora, un MiL de 30 s tarda 110–117 s y un PiL
146–194 s, recompilación incluida. En el PiL, cada cambio de Kp, Ki o Usat obliga a recompilar y
cargar el programa en el Arduino.

| Etapa | Corridas | Tiempo |
|---|---|---|
| Preparación (scripts y prueba con una corrida) | — | ~20 min |
| 1: factorial 2³ con el controlador A | 10 MiL + 2 PiL | ~20 + ~8 = **~30 min** |
| 2: factorial 2² con el controlador B | 6 MiL + 1 PiL | ~12 + ~4 = **~16 min** |
| 3: barrido final con el controlador B | 7 MiL + 3 PiL | ~14 + ~11 = **~25 min** |
| Arranque de MATLAB y figuras (por etapa) | — | ~5 min |
| **Total de cómputo** | **23 MiL + 6 PiL** | **~1 h 40 min**, repartida en tres sesiones |

El peor caso es cerca de 2.5 h, si varias corridas llegan al corte de 10 min (K alto, o Kp alto
con Usat bajo).

### Al terminar cada etapa

Opus registra aquí la tabla de resultados, los efectos estimados, si la hipótesis se sostiene y
los niveles de la etapa siguiente. Al cerrar la etapa 3, la figura 1 y la tabla pasan al informe
del Avance 3, en lugar del `\pendiente` que pide "confirmarla con una corrida en que se varíe K".
