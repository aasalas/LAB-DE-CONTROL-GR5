# Experimentos previos (histórico)

Datos y scripts de los experimentos anteriores al escenario final. **No se usan en el informe** y
los scripts ya no reproducen estos números, porque el modelo cambió después (saturación del lazo
exterior de ±0.1 a ±0.6 rad, ruido en el sensor y Hs = 2 m). Se conservan como respaldo de la
bitácora (`MODELOS/CINEMATICA/BITACORA.md`).

Condiciones comunes: Hs = 0.5 m, Tp = 10 s, 30 s, saturación del lazo exterior ±0.1 rad, sensor ideal.

| Archivos | Qué son |
|---|---|
| `exp1_etapa1.m`, `exp1_etapa1_mil.*` | Factorial 2³ en MiL: K ∈ {5, 40}, Kp ∈ {3, 20}, Usat ∈ {0.1, 1}, punto central y K = 0 |
| `exp1_etapa3.m`, `exp1_etapa3_mil.*` | Barrido de K ∈ {0, 5, 10, 15, 20, 30} en MiL con Kp = 20, Ki = 1 |
| `exp1_etapa3_pil.m`, `exp1_etapa3_pil.*` | Los mismos K = 0, 15 y 20 en el Arduino (PiL) |
| `metricas_etapa3.csv` | Tabla resumen del barrido y del PiL |

Para volver a correrlos habría que copiar los `.m` a `MODELOS/CINEMATICA/` y restaurar esas condiciones.
Los resultados del primer controlador (Kp = 6.7, K = 20) están en el historial de git
(`tres_casos.mat` y `metricas.csv`, hasta el commit `586cfb1`).
