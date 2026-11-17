# LAB-DE-CONTROL-GR5 — MARLUP

Plataforma de nivelación **MARLUP** (roll, pitch y heave) con tres actuadores
hidráulicos. Curso Laboratorio de Control, Instituto Tecnológico de Costa Rica.
Aarón Salas Alvarado, Mónica Solís Murillo, Eduardo Valle Arriola.

## Estado actual (16 nov 2026)

| | |
|---|---|
| Arquitectura | **Prealimentación pura (B):** IMU de la base → cinemática inversa (rotación inversa de la base) → 3 PI de posición. Sin lazo sobre la mesa, sin saturación, sin lazo de heave |
| Controlador | **Un solo PI en todo el proyecto: Kp = 27.5, Ki = 1**, Ts = 10 ms, en `ctrl_pi.slx` (un pistón) y `ctrl_pi3.slx` (los tres) |
| Requisito | Inclinación de la mesa **≤ 1°** en roll y pitch con oleaje de **Hs = 2 m**, Tp = 10 s |
| Resultado | Pico de pitch de 2.88° sin compensar a **0.35°**; roll de 1.52° a 0.16°. El PiL ideal en el Arduino coincide con el MiL; con el encoder no ideal, 0.44° |
| Informe del Avance 3 | [`DOCS/AVANCES/AVANCE 3/informe_avance3.pdf`](DOCS/AVANCES/AVANCE%203/informe_avance3.pdf) |
| Diseño del PI | [`MODELOS/PISTON/MODELO_MATEMATICO.md`](MODELOS/PISTON/MODELO_MATEMATICO.md) y `MODELOS/PISTON/diseno_pi.m` |
| Experimentos y decisiones | [`MODELOS/CINEMATICA/BITACORA.md`](MODELOS/CINEMATICA/BITACORA.md) |
| Cómo correrlo | Sección *PiL de la plataforma completa (3 pistones)*, más abajo |

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
El MiL es el mismo modelo con el bloque Model en modo Normal. Desde el 13 nov 2026 el PI es el
**controlador único del proyecto**, Kp = 20, Ki = 1 (diseñado con `MODELOS/PISTON/diseno_pi.m`); desde
el 16 nov 2026 es **Kp = 27.5, Ki = 1** (los resultados de esta sección son de Kp = 20).
El informe de la Actividad 3 se entregó con Kp = 60, Ki = 1 (Mp = 3.43 %, ts = 1.05 s).

| Caso | Mp (%) | tr (s) | ts 2 % (s) | e_ss (mm) | RMS(u) | RMSE vs MiL (mm) |
|---|---|---|---|---|---|---|
| MiL | 0.13 | 0.73 | 0.96 | 0.197 | 0.504 | — |
| PiL ideal | 0.13 | 0.73 | 0.96 | 0.197 | 0.504 | 0 (idéntico) |
| PiL solo cuantización ADC | 0.12 | 0.73 | 0.96 | 0.168 | 0.504 | 0.076 |
| PiL solo error de linealidad | 0.11 | 0.73 | 0.96 | 0.107 | 0.504 | 0.090 |
| PiL solo histéresis | 0.13 | 0.73 | 0.96 | 0.195 | 0.504 | 0.0019 |
| PiL no ideal (las tres) | 0.11 | 0.73 | 0.96 | 0.080 | 0.504 | 0.163 |

Requisitos: Mp < 10 % y e_ss < 2.3 mm. Se cumplen en todos los casos.

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
### Cómo correr el Processor-in-the-Loop

En las tres formas, Embedded Coder compila el controlador y lo carga al Arduino; la
planta y el sensor corren en Simulink.

**A. Un caso, para la demostración en vivo** (dentro de MATLAB):

```matlab
cd MODELOS/PISTON
demo_pil              % PiL no ideal: sesgo + histéresis + ADC
demo_pil('ideal')     % otros casos: 'ideal', 'cuant', 'lin', 'hist', 'todas'
demo_pil('mil')       % controlador en el PC (modo Normal), sin Arduino
demo_pil('todas', 'COM4')   % fijando el puerto
```

Carga los parámetros, fija el puerto, abre `PiL.slx`, corre la simulación y muestra la
gráfica sobre el MiL guardado junto con las métricas. Tarda 1–1.5 min, porque compila y
carga el código al Arduino; si la caché de compilación da problemas, recompila solo.

**B. Los 6 casos del informe** (desde la raíz del repositorio, unos 3 minutos: el primer
caso PIL compila el controlador y los siguientes reutilizan el programa):

```bash
matlab -batch "cd('MODELOS/PISTON'); run_pil"
```

Usa el último puerto serial disponible. Para fijarlo a mano:

```bash
matlab -batch "cd('MODELOS/PISTON'); PIL_PORT = 'COM4'; run_pil"
```

Escribe `resultados/` (métricas, log y CSV) y `figuras/`.

**C. Desde la interfaz de Simulink**, presionando *Run*:

```matlab
cd MODELOS/PISTON
run('../CINEMATICA/MARLUP_hydr_params.m')
pil_puerto('COM4')    % con su puerto
sens = struct('bias',0,'backlash',0,'q',1e-12,'xmin',-inf,'xmax',inf);   % sin no idealidades
open_system('PiL')
```

Presione *Run*: el bloque Controlador ya está en modo PIL. Si en una segunda corrida
aparece el error de `wrapper.mk`, ejecute `limpiar_pil` y vuelva a presionar *Run*.

**Problemas conocidos (ya resueltos en los scripts):**

| Mensaje | Causa y solución |
|---|---|
| *No Arduino Uno board detected* | El paquete no autodetecta clones CH340; `pil_puerto` fija el puerto a mano. |
| *must be 'None' or the name of a registered hardware board* | Falta el Support Package en esta versión de MATLAB (paso 1). |
| *Data type "double" is not supported for SIL or PIL* | En el AVR un double ocupa 4 bytes; la interfaz de `ctrl_pi` es `single`. |
| *gmake: wrapper.mk: No such file or directory* | Código "al día" reutilizado desde la caché; `run_pil` borra `slprj/ert/ctrl_pi` y `ctrl_pi.slxc` y reintenta. Si aparece al correr desde la interfaz, ejecute `limpiar_pil` y vuelva a correr. |

## PiL de la plataforma completa (3 pistones)

`MODELOS/CINEMATICA/Model_aaronC.slx` simula MARLUP completo (oleaje de Pierson–Moskowitz,
cinemática inversa, tres actuadores hidráulicos y la plataforma en Simscape Multibody) con los
tres controladores PI en **un solo** bloque Model en modo PIL, que referencia `ctrl_pi3.slx`.
`Model_aaron.slx` es el mismo modelo con ese bloque en modo Normal (MiL).

En el nivel principal del modelo, `Linear encoder` está en la realimentación y agrega las no
idealidades a la posición medida de cada pistón (sesgo, histéresis, ruido, ADC y rango);
`Interfaz MCU` muestrea a 10 ms y convierte a `single`, `Controlador` es el bloque PIL, e
`Interfaz actuador` reparte el comando a los pistones.

### Cómo correr el experimento

**Requisitos:** los mismos que el PiL de un pistón (MATLAB R2026a con Simulink, Embedded Coder y el
Support Package de Arduino, ver *Cómo reproducir*), más Simscape Multibody. El modelo es pesado:
con 8 GB de RAM conviene **cerrar VS Code, el navegador y demás programas** antes de simular; con
poca memoria libre la computadora se satura.

1. **Preparar el equipo.** Cerrar programas, conectar solo el Arduino UNO por USB y ver su puerto
   (`serialportlist("available")` en MATLAB o el Administrador de dispositivos). Para el MiL no
   hace falta el Arduino.
2. **Elegir el experimento** editando `MODELOS/CINEMATICA/config_pil3.m`:

   | Variable | Qué hace | Valor actual |
   |---|---|---|
   | `Kp`, `Ki` | Ganancias del PI de cada pistón (el mismo en los tres) | 27.5, 1 |
   | `Usat` | Saturación del comando de la válvula, 1 = 100 % | 1 |
   | `en_lin`, `en_hist`, `en_q` | No idealidades del sensor: linealidad (0.09 mm), histéresis (0.004 mm) y ADC de 10 bits (0.44 mm); activas por defecto | 1, 1, 1 |
   | `en_ruido`, `ruido_mm` | Ruido eléctrico en la entrada analógica, independiente por pistón, y su desviación estándar | 1, 2.2 mm |
   | `ver_mechanics` | 1 abre Mechanics Explorer (animación 3D); consume mucha memoria | 0 |

   Desde el 16 nov 2026 la plataforma usa la **arquitectura B** (prealimentación pura): la
   inclinación medida de la base entra directo a la cinemática inversa, sin lazo de nivelación,
   sin saturación y sin lazo de heave. La altura del oleaje `Hs = 2 m` está en
   `P-M SPECTRUM/Constant1`; `correr_pil3` la cambia por opción, sin abrir el modelo.
3. **Correr desde la consola de MATLAB:**

   ```matlab
   cd MODELOS/CINEMATICA
   correr_pil3('mil')                                  % MiL: controlador en el PC, sin Arduino
   correr_pil3('pil', 'Puerto', "COM8")                % PiL: controlador en el Arduino
   correr_pil3('pil', 'NoIdeal', [1 1 1 1])           % sensor no ideal (con ruido), sin editar archivos
   ```

   | Opción | Por defecto | Significado |
   |---|---|---|
   | `Hs`, `Tp` | 2, 10 | Altura significativa [m] y periodo pico [s] del oleaje |
   | `Tsim` | 30 | Tiempo simulado [s] |
   | `TIni` | 2 | Se ignora este arranque al medir [s] |
   | `Puerto` | último disponible | Puerto serial del Arduino (solo PiL) |
   | `Kp`, `Ki`, `Usat`, `NoIdeal` | los de `config_pil3.m` | Sobrescriben la configuración; `NoIdeal = [lin hist q ruido]` |
   | `Figura` | true | Grafica roll y pitch de la mesa |

   También se puede abrir el modelo y presionar *Run*: el `InitFcn` carga los parámetros y
   `config_pil3.m`. Para el PiL, antes hay que fijar el puerto con `pil3_puerto("COM8")`.
4. **Leer el resultado.** `correr_pil3` imprime el pico y el RMS de la inclinación de la mesa
   (roll y pitch, en grados) y lo compara con el requisito de **1°**. Devuelve además las
   señales completas (`t`, `roll_deg`, `pitch_deg`), el comando de las válvulas (`u`), su
   `u_rms` y el porcentaje del tiempo en saturación.
5. **Esperar.** El MiL de 30 s tarda ~2–3 min. El PiL tarda ~3 min por corrida, más ~1–2 min
   la primera vez, y cada vez que cambian `Kp`, `Ki` o `Usat`, porque el controlador se recompila
   y se carga al Arduino.

**Los casos del informe del Avance 3** (barrido de K en MiL, MiL no ideal, PiL ideal y PiL no
ideal, 30 s cada uno) se corren con `MODELOS/CINEMATICA/exp2_final.m` (~16 min) y se guardan en
`DOCS/AVANCES/AVANCE 3/resultados/exp2_final.mat`; las figuras y la tabla de métricas salen de
`DOCS/AVANCES/AVANCE 3/figuras/fig_final.m`.

### Problemas conocidos

| Síntoma | Causa y solución |
|---|---|
| Se abre Mechanics Explorer y la computadora se satura | Poner `ver_mechanics = 0` en `config_pil3.m` y, en modelos viejos, `set_param(modelo, 'SimMechanicsOpenEditorOnUpdate', 'off')`. |
| *Errors occurred while building "ctrl_pi3"* / *wrapper.mk* | Caché de compilación desactualizada. `correr_pil3` ya la limpia y reintenta una vez; a mano: `pil3_limpiar`. |
| *An error occurred while calling the SIL or PIL target connectivity implementation* | Falló la comunicación serial. Revisar el puerto y que ningún otro programa (Arduino IDE, monitor serial) lo use. `correr_pil3` reintenta una vez. |
| *File Changed On Disk* al guardar un modelo | El modelo se cambió desde otro MATLAB o desde git. Elegir *Cancel*, cerrar con `bdclose all` y volver a abrirlo. Los `.slx` son binarios y no se pueden fusionar. |
| `Unrecognized function or variable 'Kp'` al presionar *Run* | El `InitFcn` no corrió: abrir el modelo desde la carpeta `MODELOS/CINEMATICA` o ejecutar `iniciar_pil3` antes. |

## Bitácora

Registro de lo hecho en el PiL de la plataforma completa. Más reciente primero.

### 13 nov 2026: controlador único y escenario final

Detalle, datos y decisiones en [`MODELOS/CINEMATICA/BITACORA.md`](MODELOS/CINEMATICA/BITACORA.md).

- **Un solo controlador en todo el proyecto: Kp = 20, Ki = 1, K = 15.** El PI se diseñó con la
  función de transferencia identificada en lazo abierto sobre el modelo no lineal y la respuesta
  al escalón (`MODELOS/PISTON/diseno_pi.m`).
- **Requisito: inclinación de la mesa ≤ 1°** con oleaje de **Hs = 2 m** (antes 0.2° con 0.5 m).
- La saturación del lazo de nivelación pasó de ±0.1 a ±0.6 rad: con ±0.1 rad el lazo no podía
  compensar más de ~1°, porque la mesa solo realiza el 18 % del ángulo ordenado (g = 0.184).
- Se agregó ruido de 1 LSB, independiente en cada pistón, a las no idealidades del sensor.
- Resultado (30 s, K = 15): pico de pitch de 2.88° sin compensar a **0.78°** (MiL = PiL ideal =
  PiL no ideal ± 0.001°); roll de 1.52° a 0.42°. El ruido se ve en el comando de las válvulas
  (0.012 RMS) pero cambia la inclinación en menos de 0.04°.

### 13 nov 2026: experimento 1 (factorial y barrido de K)

Experimento previo al controlador único; plan, resultados y conclusiones en
[`MODELOS/CINEMATICA/BITACORA.md`](MODELOS/CINEMATICA/BITACORA.md).

### 13 nov 2026: PiL con bloque Model sobre el Arduino

> Los resultados de esta entrada son del primer controlador (Kp = 6.7, K = 20, Hs = 0.5 m,
> requisito de 0.20°). Los vigentes están en *Estado actual* y en la entrada de arriba.

- Se reemplazó el MATLAB Function que hablaba por serie con tramas propias (`pil_ctrl3`,
  `pil_arduino_3p`) por un **bloque Model en modo PIL** que referencia `ctrl_pi3.slx`, igual que el
  PiL de un pistón. El código del Arduino ahora lo genera Embedded Coder. `Model_aaronC.slx` es el
  PiL y `Model_aaron.slx` el MiL; se eliminaron los scripts viejos que dependían de la variable
  global `PIL`.
- Ganancias, saturación y no idealidades quedaron en `config_pil3.m`; `correr_pil3` las acepta
  también como opciones para iterar rápido.
- **PiL en el Arduino (COM8), solver de paso variable, 30 s, K = 20, Hs = 0.5 m,
  Kp = 6.7, Ki = 1, Usat = 1:**

  | Caso | Pico pitch (°) | RMS pitch (°) | Pico roll (°) | RMS roll (°) | RMSE pitch vs MiL (°) |
  |---|---|---|---|---|---|
  | Sin compensar (K = 0), MiL | 0.717 | 0.335 | 0.375 | 0.133 | — |
  | MiL | 0.159 | 0.073 | 0.083 | 0.029 | — |
  | PiL ideal | 0.159 | 0.073 | 0.083 | 0.029 | 0.0000 |
  | PiL no ideal (las tres) | 0.159 | 0.073 | 0.084 | 0.030 | 0.0011 |

  (Métricas con `TIni = 2 s`, sobre una malla común; el requisito es 0.20°.)
- **El PiL ideal coincide con el MiL**: error nulo en toda la corrida. El bloque PIL en un modelo
  con solver de paso variable y Simscape Multibody funciona sin cambios.
- **Las no idealidades casi no degradan la nivelación** (diferencia máxima de 0.005° en pitch).
  Es lo contrario de lo que se había predicho en el informe: el lazo exterior realimenta el
  **ángulo de la mesa**, que el modelo mide sin error; el ADC, el sesgo y la histéresis solo
  afectan al lazo interno de cada cilindro, y el lazo exterior los compensa.
- Problemas resueltos: error de sintaxis en `iniciar_pil3.m` (rompía el *Run*), caché de
  compilación del PIL (reintento automático) y saturación de memoria por Mechanics Explorer.
- **El lazo de nivelación atenúa unas 4.5 veces (-13 dB)** el pico de inclinación (pitch 0.717° a
  0.159°), menos que los -26 dB que predice el modelo simplificado 1/(1+K) con K = 20; la causa
  queda por establecer.
- **Pendiente:** tiempo de ejecución del controlador en el ATmega328P y latencia medida de un paso
  PiL.

### 12 nov 2026: integración y limpieza del repositorio

- Se fusionó la rama de Mónica (PiL de 3 pistones con tramas seriales propias, Kp = 6.7,
  Ki = 1, Usat = 0.1) en `aaron` y luego en `develop`; `develop` se publicó en GitHub.
- Se ordenó el repositorio: caché de Simulink fuera de git, duplicados y archivos sin uso
  eliminados, y se documentó el modelo del pistón en `MODELOS/PISTON/MODELO_MATEMATICO.md`.
- Se restauró `cyl.x_init = 0.23` m en `MARLUP_hydr_params.m` (referencia base de los pistones en
  el modelo de 3 pistones); `run_pil` y `demo_pil` fijan 0 para la validación de un pistón, que
  se verificó sin cambios (Mp = 3.43 %).
- Esqueleto del informe del Avance 3 en `DOCS/AVANCES/AVANCE 3/`, con la sección del modelo
  matemático y la figura del espectro de Pierson–Moskowitz.
- **Hallazgo:** el bloque de oleaje solo usa las direcciones de 0° a 90° (la dispersión
  direccional se recorta), por lo que el mar simulado tiene una altura significativa efectiva de
  ~0.22 m en lugar de 0.5 m. Falta confirmarlo con quien lo escribió.

### Validación unitaria (un pistón)

Resultados del PiL de un pistón en la sección *Resultados principales*, más arriba; el informe
está en `DOCS/INFORME_PIL`.

## Estructura del repositorio

```
CAD/                       Piezas y ensamble de SolidWorks
DOCS/
├── ENUNCIADOS/            Enunciados de las actividades 1–3
├── AVANCES/               Avances 1 y 2 (PDF), presentación del avance 1 y AVANCE 3/: informe del PiL de 3
│                          pistones, figuras/ y resultados/ (los experimentos anteriores, en resultados/previos/)
├── INFORME_PIL/           Informe de la actividad 3 (.tex, .pdf y figuras/)
├── FIGS/                  Figuras de los avances 2 y 3 y referencias del CAD
└── CERTIFICADOS/          Certificados de Simulink y Simscape
MODELOS/
├── CINEMATICA/            MARLUP completo (3 pistones)
│   ├── MARLUP_hydr_params.m   Parámetros hidráulicos (los usa también MODELOS/PISTON)
│   ├── Model_aaronC.slx       Plataforma completa con el controlador en el Arduino (PiL)
│   ├── Model_aaron.slx        La misma plataforma con el controlador en el PC (MiL)
│   ├── ctrl_pi3.slx           Los tres PI que Embedded Coder compila para el Arduino
│   ├── BITACORA.md            Plan y resultados de los experimentos (barrido de K, ...)
│   ├── config_pil3.m          Ganancias, no idealidades y visualización: se edita aquí
│   ├── correr_pil3.m          Corre el MiL o el PiL y mide la inclinación de la mesa
│   ├── exp_corridas.m         Corre una tabla de corridas y guarda métricas tras cada una
│   ├── exp2_final.m           Escenario final del informe (Hs = 2 m, K = 15; MiL y PiL)
│   └── iniciar_pil3.m, pil3_puerto.m, pil3_limpiar.m   Apoyo (los llama el modelo)
└── PISTON/                Actividad 3
    ├── PiL.slx            Planta + sensor + bloque Model en modo PIL
    ├── ctrl_pi.slx        Controlador PI que Embedded Coder compila para el Arduino
    ├── diseno_pi.m        Identifica G(s) y elige el PI por respuesta al escalón (figuras_diseno_pi.m)
    ├── run_pil.m          Corre los 6 casos, calcula métricas y genera figuras
    ├── demo_pil.m         Corre un caso (por defecto, el no ideal) para la demostración
    ├── pil_puerto.m       Fija el puerto serial del Arduino en ctrl_pi.slx
    ├── metricas_pil.m, figuras_pil.m, limpiar_pil.m
    ├── MiL.slx            Mismo lazo con el controlador en el PC (referencia MiL)
    ├── MODELO_MATEMATICO.md   Modelo, función de transferencia y justificación de Kp y Ki
    ├── resultados/        Métricas, log y CSV por caso
    └── figuras/           Figuras del informe
```
