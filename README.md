# LAB-DE-CONTROL-GR5 — MARLUP

Plataforma de nivelación **MARLUP** (roll, pitch y heave) con tres actuadores
hidráulicos. Curso Laboratorio de Control, Instituto Tecnológico de Costa Rica.
Aarón Salas Alvarado, Mónica Solís Murillo, Eduardo Valle Arriola.

## Para el revisor: Actividad 3, Processor-in-the-Loop

El modelo dinámico de **un** pistón hidráulico (cilindro Rexroth CDH1 40/28 + válvula
proporcional 4/3) corre en Simulink y el controlador PI corre en un **Arduino UNO R3**.
Ambos intercambian la posición y el comando por UART, paso a paso (*lockstep*).

| Qué revisar | Dónde |
|---|---|
| Informe (PDF) | [`DOCS/INFORME_PIL/informe_pil.pdf`](DOCS/INFORME_PIL/informe_pil.pdf) — fuente en `informe_pil.tex` |
| Video de la demostración con el Arduino | [`MODELOS/PISTON/resultados/demo/demo_pil.mp4`](MODELOS/PISTON/resultados/demo/demo_pil.mp4) |
| Modelo PiL (planta + bloque del controlador) | [`MODELOS/PISTON/PiL.slx`](MODELOS/PISTON/PiL.slx) |
| Código del microcontrolador | [`MODELOS/PISTON/pil_arduino/pil_arduino.ino`](MODELOS/PISTON/pil_arduino/pil_arduino.ino) |
| Lado Simulink: modelo del sensor y trama UART | [`MODELOS/PISTON/pil_ctrl.m`](MODELOS/PISTON/pil_ctrl.m) |
| Corridas y cálculo de métricas | [`MODELOS/PISTON/run_pil_all.m`](MODELOS/PISTON/run_pil_all.m) |
| Métricas y registro de la corrida con hardware | [`resultados/metricas.csv`](MODELOS/PISTON/resultados/metricas.csv), [`resultados/log_corridas.txt`](MODELOS/PISTON/resultados/log_corridas.txt) |
| Datos crudos por caso (t, ref, x, x medida, u, estado) | `MODELOS/PISTON/resultados/*.csv` |

### Resultados principales

Escalón de 0 a 0.40 m en t = 0.5 s, 4 s simulados, Ts = 10 ms. Corrida con el Arduino
en COM6: 401 tramas por caso y 0 errores de *checksum* (`log_corridas.txt`).

| Caso | Mp (%) | tr (s) | ts 2 % (s) | e_ss (mm) | RMS(u) | RMSE vs MiL (mm) |
|---|---|---|---|---|---|---|
| MiL (PI en MATLAB) | 3.43 | 0.73 | 1.05 | 0.016 | 0.528 | — |
| PiL ideal | 3.42 | 0.73 | 1.05 | 0.016 | 0.528 | 0.0036 |
| PiL solo cuantización ADC | 3.41 | 0.73 | 1.05 | 0.031 | 0.528 | 0.113 |
| PiL solo error de linealidad | 3.40 | 0.73 | 1.05 | 0.074 | 0.528 | 0.091 |
| PiL solo histéresis | 3.42 | 0.73 | 1.05 | 0.016 | 0.528 | 0.0062 |
| PiL no ideal (las tres) | 3.47 | 0.73 | 1.05 | 0.058 | 0.528 | 0.177 |

Requisitos: Mp < 10 % y e_ss < 2.3 mm (0.2° de nivelación). Se cumplen en todos los
casos. La no idealidad dominante es la cuantización del ADC de 10 bits.

### Qué muestra el video

Perfil de tres escalones (400 → 150 → 300 mm) con las no idealidades del sensor
activas. Se ven las tramas UART en hexadecimal en vivo, el tiempo de ida y vuelta
medido de cada trama (≈10–13 ms, del orden de Ts) y una trama con *checksum* corrupto
inyectada a propósito en t = 7 s: el Arduino responde `estado = 1` y mantiene el
último comando. El LED 13 de la placa se enciende mientras la válvula está saturada.

## Cómo reproducir

**Requisitos:** MATLAB R2026a con Simulink (el modelo PiL no usa Simscape); Arduino UNO (o clon CH340)
conectado por USB; Arduino IDE 2 (trae `arduino-cli`) con el core `arduino:avr`.
Conecte solo el Arduino: los scripts usan el último puerto serial disponible
(la demo usa `COM6` por defecto, cambiable con `demo_pil('puerto', "COMx")`).

Desde la raíz del repositorio:

```bash
matlab -batch "cd('MODELOS/PISTON'); subir_arduino"
```
Compila y sube el sketch (registro en `logs/log_subida.txt`).

```bash
matlab -batch "cd('MODELOS/PISTON'); run_pil_all"
```
Corre los 6 casos (unos 2 minutos) y escribe `resultados/` y `figuras/`. Sin Arduino
conectado corre todo en MATLAB y escribe en `resultados/sin_hw/` (esos datos no son PiL).

```bash
matlab -nodesktop -nosplash -r "cd('MODELOS/PISTON'); demo_pil"
```
Abre el tablero en vivo y espera el botón **Iniciar PiL**. Con
`demo_pil('esperar', false, 'video', true)` arranca solo y graba el MP4.

`correr_todo.m` ejecuta `pil_setup` + `subir_arduino` + `run_pil_all` y deja el
registro en `resultados/diario.txt`.

### Protocolo UART (115200 baud, 6 bytes)

| Sentido | Trama |
|---|---|
| Simulink → MCU | `0xAA` · x (uint16, 0.01 mm) · ref (uint16, 0.01 mm) · XOR |
| MCU → Simulink | `0x55` · u (int16, u·32767) · seq · estado (0 ok, 1 checksum malo) · XOR |
| Reinicio | `0xA5` + 5 bytes → responde `0x5A` y pone los estados del PI en cero |

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
    ├── MiL.slx, PiL.slx   Modelo del actuador (MiL) y modelo PiL
    ├── *.m                pil_ctrl, run_pil_all, figuras_pil, demo_pil, subir_arduino, ...
    ├── pil_arduino/       Sketch del controlador PI
    ├── figuras/           Figuras del informe (generadas por figuras_pil.m)
    ├── resultados/        Corrida con hardware: métricas, log y CSV por caso
    │   ├── demo/          Video, captura y datos de la demostración
    │   └── sin_hw/        Corrida de prueba sin Arduino (no es PiL)
    └── logs/              Registros de compilación y subida al Arduino
```

El commit de los resultados citados en el informe es `1f89753`.
