# LAB-DE-CONTROL-GR5 — MARLUP

Plataforma de nivelación **MARLUP** (roll, pitch y heave) con tres actuadores
hidráulicos. Curso Laboratorio de Control, Instituto Tecnológico de Costa Rica.
Aarón Salas Alvarado, Mónica Solís Murillo, Eduardo Valle Arriola.

## Para el revisor: Actividad 3, Processor-in-the-Loop

El modelo dinámico de **un** pistón hidráulico (cilindro Rexroth CDH1 40/28 + válvula
proporcional 4/3) corre en Simulink y el controlador PI corre en un **Arduino UNO R3**.
Ambos intercambian la posición y el comando por UART, paso a paso (*lockstep*).
El PiL se hizo de dos formas, con los mismos 6 casos y las mismas métricas:

- **PIL de Simulink** (`PiL_oficial.slx`): bloque Model en modo *Processor-in-the-loop*;
  Embedded Coder genera el código C de `ctrl_pi.slx` y lo corre en el Arduino.
- **PiL con protocolo propio** (`PiL.slx`): un bloque MATLAB Function envía tramas de
  6 bytes a un PI escrito a mano en el sketch `pil_arduino.ino`.

| Qué revisar | Dónde |
|---|---|
| Informe (PDF) | [`DOCS/INFORME_PIL/informe_pil.pdf`](DOCS/INFORME_PIL/informe_pil.pdf) — fuente en `informe_pil.tex` |
| Video de la demostración con el Arduino | [`MODELOS/PISTON/resultados/demo/demo_pil.mp4`](MODELOS/PISTON/resultados/demo/demo_pil.mp4) |
| PIL de Simulink: modelo host y controlador | [`MODELOS/PISTON/PiL_oficial.slx`](MODELOS/PISTON/PiL_oficial.slx), [`MODELOS/PISTON/ctrl_pi.slx`](MODELOS/PISTON/ctrl_pi.slx) |
| PIL de Simulink: métricas y registro | [`resultados/pil_oficial/metricas.csv`](MODELOS/PISTON/resultados/pil_oficial/metricas.csv), [`log_corridas.txt`](MODELOS/PISTON/resultados/pil_oficial/log_corridas.txt) |
| PiL propio: modelo (planta + bloque del controlador) | [`MODELOS/PISTON/PiL.slx`](MODELOS/PISTON/PiL.slx) |
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

Con el **PIL de Simulink** (`resultados/pil_oficial/metricas.csv`, 401 muestras por caso):

| Caso | Mp (%) | e_ss (mm) | RMSE vs MiL (mm) |
|---|---|---|---|
| MiL (bloque Model en modo Normal) | 3.43 | 0.014 | — |
| PiL ideal | 3.43 | 0.014 | 0 (idéntico) |
| PiL solo cuantización ADC | 3.41 | 0.024 | 0.121 |
| PiL solo error de linealidad | 3.40 | 0.076 | 0.089 |
| PiL solo histéresis | 3.42 | 0.014 | 0.0048 |
| PiL no ideal (las tres) | 3.47 | 0.047 | 0.160 |

Requisitos: Mp < 10 % y e_ss < 2.3 mm (0.2° de nivelación). Se cumplen en todos los
casos. La no idealidad dominante es la cuantización del ADC de 10 bits.

### Qué muestra el video

Perfil de tres escalones (400 → 150 → 300 mm) con las no idealidades del sensor
activas. Se ven las tramas UART en hexadecimal en vivo, el tiempo de ida y vuelta
medido de cada trama (≈10–13 ms, del orden de Ts) y una trama con *checksum* corrupto
inyectada a propósito en t = 7 s: el Arduino responde `estado = 1` y mantiene el
último comando. El LED 13 de la placa se enciende mientras la válvula está saturada.

## Cómo reproducir

Conecte **solo** el Arduino: los scripts usan el último puerto serial disponible.
Para ver cuál es, en MATLAB: `serialportlist("available")` (o en el Administrador de
dispositivos de Windows, "Puertos (COM y LPT)"). Ejecute un solo MATLAB a la vez.

### A. PIL de Simulink (`PiL_oficial.slx`)

**Requisitos:** MATLAB **R2026a** con Simulink, Embedded Coder (incluye Simulink Coder y
MATLAB Coder) y el **Simulink Support Package for Arduino Hardware**.

1. **Instalar el Support Package** (una sola vez): abra MATLAB R2026a con clic derecho →
   *Ejecutar como administrador*, escriba `supportPackageInstaller` e instale
   "Simulink Support Package for Arduino Hardware". Los paquetes son por versión: si lo
   instaló en otra versión de MATLAB, R2026a no lo ve. Para comprobarlo:
   ```matlab
   matlabshared.supportpkg.getInstalled
   ```
   Debe listar el paquete de Arduino. Cierre MATLAB al terminar.
2. **Correr los 6 casos** (unos 5 minutos; cada caso PIL compila y carga el código al Arduino):
   ```bash
   matlab -batch "cd('MODELOS/PISTON'); run_pil_oficial"
   ```
   Para fijar el puerto a mano:
   ```bash
   matlab -batch "cd('MODELOS/PISTON'); PIL_PORT = 'COM4'; run_pil_oficial"
   ```
   Escribe `resultados/pil_oficial/` (métricas, log, CSV y figuras).
3. **Desde la interfaz de Simulink:** en MATLAB, `cd MODELOS/PISTON`, luego
   `pil_puerto('COM4')` con su puerto, abra `PiL_oficial.slx` y presione *Run*. El bloque
   Controlador ya está en modo PIL (recuadro con la etiqueta "PIL"). Antes, cargue los
   parámetros con `run('../CINEMATICA/MARLUP_hydr_params.m')` y defina `sens` como en
   `run_pil_oficial.m` (por ejemplo, sin no idealidades:
   `sens = struct('bias',0,'backlash',0,'q',1e-12,'xmin',-inf,'xmax',inf)`).

`pil_oficial_setup.m` vuelve a generar `ctrl_pi.slx` y `PiL_oficial.slx` desde `PiL.slx`;
solo hace falta si se cambia el diseño.

**Problemas conocidos (ya resueltos en los scripts):**

| Mensaje | Causa y solución |
|---|---|
| *No Arduino Uno board detected* | El paquete no autodetecta clones CH340; `pil_puerto` fija el puerto a mano. |
| *must be 'None' or the name of a registered hardware board* | Falta el Support Package en esta versión de MATLAB (paso 1). |
| *Data type "double" is not supported for SIL or PIL* | En el AVR un double ocupa 4 bytes; la interfaz de `ctrl_pi` es `single`. |
| *gmake: wrapper.mk: No such file or directory* | Código "al día" reutilizado desde la caché; `run_pil_oficial` borra `slprj/ert/ctrl_pi` y `ctrl_pi.slxc` antes de cada caso PIL. Si aparece al correr desde la interfaz, borre esa carpeta y ese archivo y vuelva a correr. |

El PIL deja su propio programa en el Arduino. Para volver a usar el PiL propio o la
demo, primero cargue de nuevo el sketch con `subir_arduino`.

### B. PiL con protocolo propio (`PiL.slx`) y demo

**Requisitos:** MATLAB R2026a con Simulink (no usa Simscape) y Arduino IDE 2
(trae `arduino-cli`) con el core `arduino:avr`. La demo usa `COM6` por defecto,
cambiable con `demo_pil('puerto', "COMx")`.

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
    ├── PiL_oficial.slx    PIL de Simulink: planta + sensor + bloque Model en modo PIL
    ├── ctrl_pi.slx        Controlador PI que Embedded Coder compila para el Arduino
    ├── MiL.slx, PiL.slx   Modelo del actuador (MiL) y PiL con protocolo propio
    ├── *.m                run_pil_oficial, pil_puerto, pil_oficial_setup, metricas_pil,
    │                      pil_ctrl, run_pil_all, figuras_pil, demo_pil, subir_arduino, ...
    ├── pil_arduino/       Sketch del controlador PI (PiL propio)
    ├── figuras/           Figuras del informe (generadas por figuras_pil.m)
    ├── resultados/        PiL propio con hardware: métricas, log y CSV por caso
    │   ├── pil_oficial/   PIL de Simulink: métricas, log, CSV y figuras
    │   ├── demo/          Video, captura y datos de la demostración
    │   └── sin_hw/        Corrida de prueba sin Arduino (no es PiL)
    └── logs/              Registros de compilación y subida al Arduino
```

Los resultados del PiL propio citados en el informe están en el commit `1f89753`;
los del PIL de Simulink, en `8970620`.
