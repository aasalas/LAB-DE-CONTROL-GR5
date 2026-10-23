"""Corre el benchmark del ESP32-C6 (firmware esp32c6_benchmark.ino) y grafica los resultados.

Uso:  python correr_benchmark.py [COMx]        (por defecto COM7)
Escribe resultados/*.csv y figuras/*.png|pdf junto a este archivo.
"""
import csv
import sys
import time
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import serial

PUERTO = sys.argv[1] if len(sys.argv) > 1 else "COM7"
AQUI = Path(__file__).resolve().parent
RES = AQUI / "resultados"
FIG = AQUI / "figuras"
RES.mkdir(exist_ok=True)
FIG.mkdir(exist_ok=True)
plt.rcParams.update({"font.size": 10, "axes.grid": True, "grid.alpha": 0.3, "figure.dpi": 110})
AZUL, ROJO, VERDE, GRIS = "#0072B2", "#D55E00", "#009E73", "#666666"


def prueba(sp, cmd, timeout=180):
    """Envia un comando y devuelve las lineas CSV hasta DONE."""
    sp.reset_input_buffer()
    sp.write(cmd.encode())
    lineas, t0 = [], time.time()
    while time.time() - t0 < timeout:
        l = sp.readline().decode(errors="replace").strip()
        if not l:
            continue
        if l.startswith("DONE"):
            return lineas
        lineas.append(l.split(","))
    raise TimeoutError(f"la prueba {cmd} no termino")


def guardar(nombre, encabezado, filas):
    with open(RES / nombre, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(encabezado)
        w.writerows(filas)


def rtt(sp, n=2000):
    """Tiempo de ida y vuelta de una trama de 6 bytes (como en un paso de PiL)."""
    sp.reset_input_buffer()
    t = []
    for k in range(n):
        x, r = int(39000 + 50 * np.sin(k / 20)), 40000
        f = bytearray([0xAA, x & 0xFF, x >> 8, r & 0xFF, r >> 8, 0])
        f[5] = f[0] ^ f[1] ^ f[2] ^ f[3] ^ f[4]
        t0 = time.perf_counter()
        sp.write(f)
        resp = sp.read(6)
        t.append((time.perf_counter() - t0) * 1e3)
        if len(resp) != 6 or resp[0] != 0x55:
            raise RuntimeError(f"respuesta invalida en la trama {k}: {resp!r}")
    return np.array(t)


def guardar_fig(fig, nombre):
    fig.tight_layout()
    for ext in ("png", "pdf"):
        fig.savefig(FIG / f"{nombre}.{ext}")
    plt.close(fig)


with serial.Serial(PUERTO, 115200, timeout=2) as sp:
    time.sleep(1.5)
    info = prueba(sp, "I")[0]
    print("Placa:", ",".join(info[1:]))
    print("Aritmetica...");   A = prueba(sp, "A")
    print("Paso del PI...");  P = prueba(sp, "P")
    print("ADC...");          D = prueba(sp, "D")
    print("Lazo en tiempo real (unos segundos)...")
    L = prueba(sp, "L")
    print("RTT de tramas por USB...")
    T = rtt(sp)

# ---------------- CSV ----------------
arit = [(a[1], float(a[2]), float(a[3])) for a in A if a[0] == "ARIT"]
pi = np.array([[int(a[2]), int(a[3])] for a in P if a[0] == "PI"])
mhz = int(next(a for a in P if a[0] == "PIINFO")[1])
lazo = [(a[1], int(a[2]), int(a[3]), *map(float, a[4:])) for a in L if a[0] == "LOOP"]
adc = next(a for a in D if a[0] == "ADC")
guardar("aritmetica.csv", ["operacion", "ns_por_op", "Mops_s"], arit)
guardar("paso_pi_ciclos.csv", ["ciclos_float", "ciclos_double"], pi.tolist())
guardar("lazo.csv", ["variante", "hz", "N", "hz_logrado", "lat_media_us", "lat_p50_us",
                     "lat_p99_us", "lat_max_us", "plazos_perdidos_pct"], lazo)
guardar("adc.csv", ["pin", "us_por_lectura", "lecturas_s", "media", "desv", "min", "max"], [adc[1:]])
guardar("rtt_ms.csv", ["rtt_ms"], [[v] for v in T])

# ---------------- figuras ----------------
# 1) aritmetica
fig, ax = plt.subplots(figsize=(7, 3.6))
nombres = [a[0] for a in arit]
mops = [a[2] for a in arit]
col = [VERDE if "int" in n else (AZUL if ("float" in n or "sqrt" in n) else ROJO) for n in nombres]
b = ax.barh(nombres, mops, color=col)
ax.set_xscale("log")
ax.invert_yaxis()
ax.set_xlabel("millones de operaciones por segundo (escala log)")
ax.set_title(f"ESP32-C6 a {mhz} MHz: aritmética (sin FPU)")
for rect, (n, ns, m) in zip(b, arit):
    ax.text(m * 1.08, rect.get_y() + rect.get_height() / 2, f"{m:.1f} Mops/s · {ns:.0f} ns",
            va="center", fontsize=8)
ax.set_xlim(right=max(mops) * 6)
guardar_fig(fig, "1_aritmetica")

# 2) paso del PI
us = pi / mhz
fig, ax = plt.subplots(figsize=(7, 3.6))
bins = np.linspace(0, us.max() * 1.05, 60)
ax.hist(us[:, 0], bins=bins, color=AZUL, alpha=0.8, label=f"float: mediana {np.median(us[:,0]):.2f} µs")
ax.hist(us[:, 1], bins=bins, color=ROJO, alpha=0.7, label=f"double: mediana {np.median(us[:,1]):.2f} µs")
ax.set_xlabel("duración de un paso del PI (µs)")
ax.set_ylabel("pasos")
ax.set_title("Paso del PI de MARLUP (Tustin + clamping), 2000 muestras")
fmax_f, fmax_d = 1e6 / np.median(us[:, 0]), 1e6 / np.median(us[:, 1])
ax.legend(title=f"tope teórico: {fmax_f/1e3:.0f} kHz (float), {fmax_d/1e3:.0f} kHz (double)")
guardar_fig(fig, "2_paso_pi")

# 3) lazo en tiempo real: frecuencia lograda y jitter
fig, (a1, a2) = plt.subplots(1, 2, figsize=(10, 3.8))
etiq = {"float": "PI float", "double": "PI double", "adc+pi": "lectura ADC + PI float"}
for var, c in (("float", AZUL), ("double", ROJO), ("adc+pi", VERDE)):
    f = [r for r in lazo if r[0] == var]
    hz = np.array([r[1] for r in f])
    logrado = np.array([r[3] for r in f])
    tope = max(r[3] for r in f)
    a1.loglog(hz, logrado, "o-", color=c, label=f"{etiq[var]}: tope ≈ {tope/1e3:.0f} kHz")
    a2.loglog(hz, [max(r[6], 0.01) for r in f], "o-", color=c, label=f"{etiq[var]} (p99)")
a1.loglog([1e3, 1e6], [1e3, 1e6], ":", color=GRIS, label="ideal (lograda = pedida)")
a1.axvline(100, color=GRIS, lw=0.8)
a1.set_xlim(70, 1.5e6)
a1.text(115, 3e5, "MARLUP\n100 Hz", color=GRIS, fontsize=8)
a1.set_xlabel("frecuencia pedida (Hz)")
a1.set_ylabel("frecuencia lograda (Hz)")
a1.set_title("¿Hasta dónde aguanta el lazo?")
a1.legend(fontsize=7, loc="lower right")
a2.set_xlabel("frecuencia pedida (Hz)")
a2.set_ylabel("retraso p99 respecto al instante ideal (µs)")
a2.set_title("Jitter del lazo (percentil 99)")
a2.legend(fontsize=7)
guardar_fig(fig, "3_lazo_tiempo_real")

# 4) RTT por USB
fig, ax = plt.subplots(figsize=(7, 3.6))
ax.hist(T, bins=np.logspace(np.log10(T.min() * 0.9), np.log10(12), 80), color=AZUL)
ax.set_xscale("log")
ax.axvline(10, color=ROJO, ls="--")
ax.text(6.5, ax.get_ylim()[1] * 0.85, "Ts = 10 ms", color=ROJO, ha="right")
ax.set_xlabel("tiempo de ida y vuelta de una trama de 6 bytes (ms, escala log)")
ax.set_ylabel("tramas")
ax.set_title(f"USB-Serial/JTAG: media {T.mean():.3f} ms, p99 {np.percentile(T, 99):.3f} ms, "
             f"máx. {T.max():.3f} ms")
guardar_fig(fig, "4_rtt_usb")

# ---------------- resumen ----------------
print("\nRESUMEN")
for n, ns, m in arit:
    print(f"  {n:16s} {ns:9.1f} ns/op  {m:9.2f} Mops/s")
print(f"  PI float  mediana {np.median(us[:,0]):.2f} us (max {us[:,0].max():.2f}) -> {fmax_f/1e3:.0f} kHz teorico")
print(f"  PI double mediana {np.median(us[:,1]):.2f} us (max {us[:,1].max():.2f}) -> {fmax_d/1e3:.0f} kHz teorico")
for var in ("float", "double", "adc+pi"):
    ok = [r for r in lazo if r[0] == var and r[8] == 0]
    print(f"  lazo {var:7s}: mayor frecuencia sin plazos perdidos = {max(r[1] for r in ok) if ok else 0} Hz")
print(f"  ADC: {float(adc[2]):.1f} us por lectura -> {float(adc[3]):.0f} lecturas/s")
print(f"  RTT USB: media {T.mean():.3f} ms, p99 {np.percentile(T,99):.3f} ms, max {T.max():.3f} ms")
print(f"Figuras en {FIG}")
