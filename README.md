# LAB-DE-CONTROL-GR5 — MARLUP

Plataforma de nivelación **MARLUP** (roll, pitch y heave) con tres actuadores
hidráulicos. Curso Laboratorio de Control, Instituto Tecnológico de Costa Rica.
Aarón Salas Alvarado, Mónica Solís Murillo, Eduardo Valle Arriola.

## Para el revisor: Actividad 3, Processor-in-the-Loop

El modelo dinámico de **un** pistón hidráulico (cilindro Rexroth CDH1 40/28 + válvula
proporcional 4/3) corre en Simulink y el controlador PI corre en un **Arduino UNO R3**
con el flujo *Processor-in-the-Loop* de Simulink: Embedded Coder genera el código C de
`ctrl_pi.slx`, lo compila y lo carga en la placa, y el bloque Model de `PiL.slx` en modo
PIL intercambia con ella la posición y el comando por UART, paso a paso (*lockstep*).

| Qué revisar | Dónde |
|---|---|
| Informe (PDF) | [`DOCS/INFORME_PIL/informe_pil.pdf`](DOCS/INFORME_PIL/informe_pil.pdf) — fuente en `informe_pil.tex` |
| Modelo host: planta, sensor con no idealidades y bloque Model en modo PIL | [`MODELOS/PISTON/PiL.slx`](MODELOS/PISTON/PiL.slx) |
| Controlador que corre en el Arduino | [`MODELOS/PISTON/ctrl_pi.slx`](MODELOS/PISTON/ctrl_pi.slx) |
| Corridas, métricas y figuras | [`MODELOS/PISTON/run_pil.m`](MODELOS/PISTON/run_pil.m) |
| Métricas y registro | [`resultados/metricas.csv`](MODELOS/PISTON/resultados/metricas.csv), [`resultados/log_corridas.txt`](MODELOS/PISTON/resultados/log_corridas.txt) |
| Datos crudos por caso (t, ref, x, x medida, u) | `MODELOS/PISTON/resultados/*.csv` |

### Resultados principales

Escalón de 0 a 0.40 m en t = 0.5 s, 4 s simulados, Ts = 10 ms, 401 muestras por caso.
El MiL es el mismo modelo con el bloque Model en modo Normal.

| Caso | Mp (%) | tr (s) | ts 2 % (s) | e_ss (mm) | RMS(u) | RMSE vs MiL (mm) |
|---|---|---|---|---|---|---|
| MiL | 3.43 | 0.73 | 1.05 | 0.014 | 0.528 | — |
| PiL ideal | 3.43 | 0.73 | 1.05 | 0.014 | 0.528 | 0 (idéntico) |
| PiL solo cuantización ADC | 3.41 | 0.73 | 1.05 | 0.024 | 0.528 | 0.121 |
| PiL solo error de linealidad | 3.40 | 0.73 | 1.05 | 0.076 | 0.528 | 0.089 |
| PiL solo histéresis | 3.42 | 0.73 | 1.05 | 0.014 | 0.528 | 0.0048 |
| PiL no ideal (las tres) | 3.47 | 0.73 | 1.05 | 0.047 | 0.528 | 0.160 |

Requisitos: Mp < 10 % y e_ss < 2.3 mm (0.2° de nivelación). Se cumplen en todos los
casos. La no idealidad dominante es la cuantización del ADC de 10 bits.

## Cómo reproducir

**Requisitos:** MATLAB **R2026a** con Simulink, Embedded Coder (incluye Simulink Coder y
MATLAB Coder) y el **Simulink Support Package for Arduino Hardware**; Arduino UNO (o clon
CH340) conectado por USB.

1. **Instalar el Support Package** (una sola vez): abra MATLAB R2026a con clic derecho →
   *Ejecutar como administrador*, escriba `supportPackageInstaller` e instale
   "Simulink Support Package for Arduino Hardware". Los paquetes son por versión: si lo
   instaló en otra versión de MATLAB, R2026a no lo ve. Para comprobarlo:
   ```matlab
   matlabshared.supportpkg.getInstalled
   ```
   Debe listar el paquete de Arduino. Cierre MATLAB al terminar.
2. **Conectar solo el Arduino.** Para ver su puerto: `serialportlist("available")` en
   MATLAB, o el Administrador de dispositivos de Windows ("Puertos (COM y LPT)").
   Ejecute un solo MATLAB a la vez.
3. **Correr los 6 casos** desde la raíz del repositorio (unos 3 minutos: el primer caso
   PIL compila el controlador y lo carga al Arduino; los siguientes reutilizan el programa):
   ```bash
   matlab -batch "cd('MODELOS/PISTON'); run_pil"
   ```
   Usa el último puerto serial disponible. Para fijarlo a mano:
   ```bash
   matlab -batch "cd('MODELOS/PISTON'); PIL_PORT = 'COM4'; run_pil"
   ```
   Escribe `resultados/` (métricas, log y CSV) y `figuras/`.
4. **Desde la interfaz de Simulink** (opcional): en MATLAB, `cd MODELOS/PISTON`,
   `run('../CINEMATICA/MARLUP_hydr_params.m')`, `pil_puerto('COM4')` con su puerto y,
   sin no idealidades, `sens = struct('bias',0,'backlash',0,'q',1e-12,'xmin',-inf,'xmax',inf)`.
   Abra `PiL.slx` y presione *Run*: el bloque Controlador ya está en modo PIL.

### Demostración en vivo

Para correr un solo caso con el Arduino y verlo sobre el MiL guardado (gráfica y métricas):

```matlab
cd MODELOS/PISTON
demo_pil              % PiL no ideal: sesgo + histéresis + ADC
demo_pil('ideal')     % otros casos: 'ideal', 'cuant', 'lin', 'hist', 'todas'
demo_pil('mil')       % controlador en el PC (modo Normal), sin Arduino
demo_pil('todas', 'COM4')   % fijando el puerto
```

Carga los parámetros, fija el puerto, abre `PiL.slx` y corre la simulación (1–1.5 min la
primera vez, porque compila y carga el código al Arduino). Si la caché de compilación da
problemas, recompila solo.

**Problemas conocidos (ya resueltos en los scripts):**

| Mensaje | Causa y solución |
|---|---|
| *No Arduino Uno board detected* | El paquete no autodetecta clones CH340; `pil_puerto` fija el puerto a mano. |
| *must be 'None' or the name of a registered hardware board* | Falta el Support Package en esta versión de MATLAB (paso 1). |
| *Data type "double" is not supported for SIL or PIL* | En el AVR un double ocupa 4 bytes; la interfaz de `ctrl_pi` es `single`. |
| *gmake: wrapper.mk: No such file or directory* | Código "al día" reutilizado desde la caché; `run_pil` borra `slprj/ert/ctrl_pi` y `ctrl_pi.slxc` y reintenta. Si aparece al correr desde la interfaz, borre esa carpeta y ese archivo y vuelva a correr. |

## Estructura del repositorio

```
CAD/                       Piezas y ensamble de SolidWorks
DOCS/
├── ENUNCIADOS/            Enunciados de las actividades 1–3
├── AVANCES/               Avances 1 y 2 (PDF) y presentación del avance 1
├── INFORME_PIL/           Informe de la actividad 3 (.tex, .pdf y figuras/)
├── FIGS/                  Figuras de los avances 2 y 3
└── CERTIFICADOS/          Certificados de Simulink y Simscape
MODELOS/
├── CINEMATICA/            Modelo completo de MARLUP (Model_aaron.slx) y
│                          parámetros hidráulicos MARLUP_hydr_params.m (los usa el PiL)
└── PISTON/                Actividad 3
    ├── PiL.slx            Planta + sensor + bloque Model en modo PIL
    ├── ctrl_pi.slx        Controlador PI que Embedded Coder compila para el Arduino
    ├── run_pil.m          Corre los 6 casos, calcula métricas y genera figuras
    ├── demo_pil.m         Corre un caso (por defecto, el no ideal) para la demostración
    ├── pil_puerto.m       Fija el puerto serial del Arduino en ctrl_pi.slx
    ├── metricas_pil.m, figuras_pil.m, limpiar_pil.m
    ├── MiL.slx, parameters.m   Modelo del actuador del Avance 2
    ├── resultados/        Métricas, log y CSV por caso
    └── figuras/           Figuras del informe
```
