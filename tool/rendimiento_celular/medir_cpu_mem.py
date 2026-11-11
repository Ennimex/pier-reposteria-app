"""tool/rendimiento_celular/medir_cpu_mem.py — CPU y memoria de «Pier DEV» (modo profile) en el celular (#355).

Mide las mismas escenas que integration_test/rendimiento/rendimiento_test.dart (arranque con la sesión guardada,
catálogo y checkout hasta «Finalizar Pedido»), manejadas con `adb shell input`, mientras lee `top` (CPU) o
`dumpsys meminfo` (memoria) del celular. Método, condiciones y umbrales: docs/pruebas-rendimiento-celular.md.

Uso, con «Pier DEV» abierta en el Inicio, con sesión y con un producto en el carrito:
  python tool/rendimiento_celular/medir_cpu_mem.py reposo  <carpeta> 1 cpu   # 30 s quieta en el Inicio
  python tool/rendimiento_celular/medir_cpu_mem.py escenas <carpeta> 3 cpu   # 3 repeticiones, solo CPU
  python tool/rendimiento_celular/medir_cpu_mem.py escenas <carpeta> 3 mem   # 3 repeticiones, solo memoria
  python tool/rendimiento_celular/medir_cpu_mem.py fuga    <carpeta> 5 mem   # 5 vueltas sin cerrar la app

Variables: DISPOSITIVO (la serie que da `adb devices`; sin ella usa el único celular conectado) e
IGNORAR_CONDICIONES=1 para medir aunque la batería esté en 50 % o menos o el celular a 35 °C o más (queda anotado).

Las coordenadas están en coords.json. Antes de CADA toque revisa qué app está al frente (dumpsys window →
mCurrentFocus) y se detiene si no es Pier DEV. Nunca toca «Finalizar Pedido» ni «Pagar»: no crea pedidos ni pagos.
"""
import json
import os
import re
import statistics
import subprocess
import sys
import threading
import time

ADB = ["adb"] + (["-s", os.environ["DISPOSITIVO"]] if os.environ.get("DISPOSITIVO") else [])
PKG = "mx.com.pierreposteria.dev"
AQUI = os.path.dirname(os.path.abspath(__file__))
C = json.load(open(os.path.join(AQUI, "coords.json"), encoding="utf-8"))

# Condiciones de la medición (docs/pruebas-rendimiento-celular.md).
BATERIA_MINIMA = 50      # %: se mide con más de esto
TEMPERATURA_MAXIMA = 35  # °C: se mide con menos de esto


def sh(cmd, timeout=60):
    r = subprocess.run(ADB + ["shell", cmd], capture_output=True, text=True, timeout=timeout,
                       encoding="utf-8", errors="replace")
    return r.stdout


def al_frente():
    s = sh("dumpsys window | grep -E 'mCurrentFocus='")
    m = re.search(r"mCurrentFocus=Window\{\S+ \S+ ([^}/ ]+)", s)
    return m.group(1) if m else s.strip()


def revisar_frente(esperado=PKG):
    f = al_frente()
    if f != esperado:
        raise SystemExit(f"ALTO: al frente está «{f}», se esperaba «{esperado}». No se toca nada.")


def tocar(nombre):
    revisar_frente()
    x, y = C[nombre]
    sh(f"input tap {x} {y}")


def deslizar(sentido):
    revisar_frente()
    x = C["lista_x"]
    a, b = (1800, 600) if sentido < 0 else (600, 1800)   # 1,200 px en 100 ms
    sh(f"input swipe {x} {a} {x} {b} 100")


def atras():
    revisar_frente()
    sh("input keyevent 4")


# ---------------------------------------------------------------- muestreo
class Muestreo:
    """Lee la CPU (top, una vez por segundo) o el TOTAL PSS (dumpsys meminfo, en bucle) con la hora de cada
    lectura. Van en pasadas separadas: dumpsys meminfo le pide a la app medir su memoria y le sube la CPU."""

    def __init__(self, cpu=True, mem=True):
        self.con_cpu, self.con_mem = cpu, mem
        self.proc_top = None
        self.cpu = []   # (t, %cpu, pid)
        self.pss = []   # (t, kB)
        self.alto = False
        self.hilos = []

    def _top(self):
        p = subprocess.Popen(ADB + ["shell", "top -b -d 1 -n 100000 -o PID,%CPU,RES,ARGS"],
                             stdout=subprocess.PIPE, text=True, encoding="utf-8", errors="replace")
        self.proc_top = p
        for linea in p.stdout:
            if self.alto:
                break
            if PKG in linea:
                partes = linea.split()
                try:
                    self.cpu.append((time.time(), float(partes[1]), partes[0]))
                except (ValueError, IndexError):
                    pass
        p.kill()

    def _pss(self):
        while not self.alto:
            s = sh(f"dumpsys meminfo {PKG}")
            t = time.time()
            m = re.search(r"TOTAL PSS:\s+(\d+)", s) or re.search(r"^\s*TOTAL\s+(\d+)", s, re.M)
            if m:
                self.pss.append((t, int(m.group(1))))
            time.sleep(0.5)

    def empezar(self):
        if self.con_cpu:
            self.hilos.append(threading.Thread(target=self._top, daemon=True))
        if self.con_mem:
            self.hilos.append(threading.Thread(target=self._pss, daemon=True))
        for h in self.hilos:
            h.start()
        time.sleep(3)   # que top ya esté imprimiendo

    def parar(self):
        self.alto = True
        if self.proc_top:
            self.proc_top.kill()
        time.sleep(1.5)


def pss_ahora():
    s = sh(f"dumpsys meminfo {PKG}")
    m = re.search(r"TOTAL PSS:\s+(\d+)", s) or re.search(r"^\s*TOTAL\s+(\d+)", s, re.M)
    return int(m.group(1)) if m else None


def bateria():
    s = sh("dumpsys battery")
    return int(re.search(r"level: (\d+)", s).group(1)), int(re.search(r"temperature: (\d+)", s).group(1)) / 10


def esperar_inicio(limite=30):
    """Fuera de la medición: confirma con uiautomator que se ve la barra de abajo. Los acentos llegan mal por
    adb en Windows, así que se buscan textos sin acentos."""
    fin = time.time() + limite
    while time.time() < fin:
        sh("uiautomator dump /sdcard/ui_medicion.xml")
        x = sh("cat /sdcard/ui_medicion.xml")
        if "Inicio" in x and "Carrito" in x and "Pesta" in x:
            return x
        time.sleep(1)
    raise SystemExit("ALTO: no apareció la barra de abajo")


def ver_pantalla():
    sh("uiautomator dump /sdcard/ui_medicion.xml")
    return sh("cat /sdcard/ui_medicion.xml")


# ---------------------------------------------------------------- escenas
def escena_arranque(marcas, i):
    sh(f"am force-stop {PKG}")
    time.sleep(3)
    t0 = time.time()
    sh(f"am start -W -n {C['componente']}")
    time.sleep(C["arranque_s"])        # splash + Inicio + 3 s de ventana
    marcas.append(("arranque", i, t0, time.time()))


def escena_catalogo(marcas, i):
    tocar("tab_catalogo")
    time.sleep(5)                      # fuera de la medición, como la prueba
    t0 = time.time()
    for sentido in (-1, 1):
        for _ in range(5):
            deslizar(sentido)
            time.sleep(1)
    marcas.append(("catalogo", i, t0, time.time()))


def escena_checkout(marcas, i):
    t0 = time.time()
    tocar("tab_carrito")
    time.sleep(C["carrito_s"])
    tocar("proceder_al_pago")
    time.sleep(C["checkout_s"])        # hasta ver «Finalizar Pedido» + 3 s de ventana
    marcas.append(("checkout", i, t0, time.time()))


def resumir(m, marcas, reposo_cpu):
    """Por escena: CPU promedio y máxima dentro, promedio de los 10 s siguientes, segundos hasta 3 lecturas
    seguidas en reposo, y TOTAL PSS al terminar (primera lectura después del fin) y máximo."""
    filas = []
    for nombre, i, t0, t1 in marcas:
        dentro = [c for t, c, _ in m.cpu if t0 <= t <= t1]
        despues = [(t, c) for t, c, _ in m.cpu if t1 < t <= t1 + 10]
        pss_dentro = [k for t, k in m.pss if t0 <= t <= t1]
        pss_fin = next((k for t, k in m.pss if t >= t1), None)
        vuelta = None
        for j in range(len(despues) - 2):
            if all(c <= reposo_cpu for _, c in despues[j:j + 3]):
                vuelta = round(despues[j][0] - t1, 1)
                break
        filas.append({
            "escena": nombre, "rep": i, "duracion_s": round(t1 - t0, 1),
            "cpu_prom": round(statistics.mean(dentro), 1) if dentro else None,
            "cpu_max": max(dentro) if dentro else None, "n_cpu": len(dentro),
            "cpu_prom_10s_despues": round(statistics.mean([c for _, c in despues]), 1) if despues else None,
            "s_hasta_reposo": vuelta,
            "pss_fin_mb": round(pss_fin / 1024, 1) if pss_fin else None,
            "pss_max_mb": round(max(pss_dentro + ([pss_fin] if pss_fin else [])) / 1024, 1)
            if (pss_dentro or pss_fin) else None,
            "n_pss": len(pss_dentro),
        })
    return filas


def main():
    if len(sys.argv) < 3 or sys.argv[1] not in ("reposo", "escenas", "fuga"):
        raise SystemExit(__doc__)
    modo, salida = sys.argv[1], sys.argv[2]
    n = int(sys.argv[3]) if len(sys.argv) > 3 else 3
    que = sys.argv[4] if len(sys.argv) > 4 else "cpu"
    os.makedirs(salida, exist_ok=True)

    nivel, temp = bateria()
    condiciones = nivel > BATERIA_MINIMA and temp < TEMPERATURA_MAXIMA
    print(f"batería al {nivel} % ({temp} °C)")
    if not condiciones and os.environ.get("IGNORAR_CONDICIONES") != "1":
        raise SystemExit(f"ALTO: se mide con la batería arriba de {BATERIA_MINIMA} % y el celular debajo de "
                         f"{TEMPERATURA_MAXIMA} °C (IGNORAR_CONDICIONES=1 para medir igual y dejarlo anotado).")
    info = {"modo": modo, "que": que, "bateria_inicio": nivel, "temp_inicio": temp,
            "condiciones_cumplidas": condiciones, "inicio": time.strftime("%H:%M:%S")}
    m = Muestreo(cpu=que in ("cpu", "ambos"), mem=que in ("mem", "ambos"))
    marcas = []

    if modo == "reposo":
        revisar_frente()
        esperar_inicio()
        m.empezar()
        t0 = time.time()
        time.sleep(30)
        marcas.append(("reposo", 1, t0, time.time()))
        m.parar()
        datos = [c for t, c, _ in m.cpu if t0 <= t] or [0]
        info["reposo"] = {"cpu_prom": round(statistics.mean(datos), 2), "cpu_mediana": statistics.median(datos),
                          "cpu_p90": sorted(datos)[int(len(datos) * 0.9) - 1], "cpu_max": max(datos),
                          "n": len(datos),
                          "pss_mb": [round(k / 1024, 1) for _, k in m.pss]}

    elif modo == "escenas":
        m.empezar()
        for i in range(1, n + 1):
            escena_arranque(marcas, i)
            time.sleep(10)                         # 10 s después, sin tocar
            esperar_inicio()                       # verificación fuera de la ventana
            escena_catalogo(marcas, i)
            time.sleep(10)
            x = ver_pantalla()
            if "Proceder al Pago" in x or "Finalizar Pedido" in x:
                raise SystemExit("ALTO: pantalla inesperada antes del checkout")
            escena_checkout(marcas, i)
            time.sleep(10)
            x = ver_pantalla()
            if "Finalizar Pedido" not in x:
                raise SystemExit("ALTO: no se llegó a «Finalizar Pedido» (¿el carrito está vacío?)")
            atras()                                # de regreso al carrito, sin tocar nada del pago
            time.sleep(3)
            tocar("tab_inicio")
            time.sleep(3)
        m.parar()
        info["filas"] = resumir(m, marcas, C["reposo_cpu"])

    elif modo == "fuga":
        revisar_frente()
        sh(f"am force-stop {PKG}")
        time.sleep(3)
        sh(f"am start -W -n {C['componente']}")
        esperar_inicio()
        time.sleep(10)
        vueltas = [("0 (recién abierta)", pss_ahora())]
        for v in range(1, n + 1):
            tocar("tab_catalogo")
            time.sleep(5)
            for sentido in (-1, 1):
                for _ in range(5):
                    deslizar(sentido)
                    time.sleep(1)
            tocar("tab_carrito")
            time.sleep(C["carrito_s"])
            tocar("proceder_al_pago")
            time.sleep(C["checkout_s"])
            x = ver_pantalla()
            if "Finalizar Pedido" not in x:
                raise SystemExit("ALTO: no se llegó a «Finalizar Pedido» (¿el carrito está vacío?)")
            atras()
            time.sleep(3)
            tocar("tab_inicio")
            time.sleep(5)
            vueltas.append((str(v), pss_ahora()))
        info["vueltas"] = [(v, round(k / 1024, 1)) for v, k in vueltas]

    nivel, temp = bateria()
    info.update({"bateria_fin": nivel, "temp_fin": temp, "fin": time.strftime("%H:%M:%S")})
    with open(os.path.join(salida, f"cpu_mem_{modo}_{que}.json"), "w", encoding="utf-8") as f:
        json.dump({"info": info, "marcas": marcas, "cpu": m.cpu, "pss": m.pss}, f, ensure_ascii=False, indent=1)
    print(json.dumps(info, ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()
