#!/usr/bin/env bash
# tool/flujos_entorno_aislado.sh — corre en el emulador los flujos del
# entorno aislado y deja su reporte JSON (trabajo «Flujos de compra, reseña
# y entrega en el entorno aislado» de .github/workflows/integracion.yml).
#
# Uso:
#   bash tool/flujos_entorno_aislado.sh <reporte.json> flutter test <prueba.dart>... <opciones>
#
# A veces la GPU emulada no le responde a la app cuando se abre (#375):
# Android la marca como «isn't responding» y flutter test la espera sin
# límite. Mientras corren las pruebas, el script vigila: si la app queda así,
# o si flutter test pasa 10 min sin escribir nada, lo corta y vuelve a
# correr una sola vez los archivos que no terminaron. El cuelgue pasa al
# abrir la app, antes de que empiece la prueba, así que el reintento no
# repite datos en la base. El reporte junta los dos intentos en orden, como
# los lee el resumen de evidencias.
#
# Termina con el código de flutter test (falla si falló una prueba en
# cualquiera de los dos intentos), o con 124 si también el reintento se
# cortó. VIGILANTE_INTERVALO y VIGILANTE_SILENCIO (segundos) solo los cambian
# las pruebas del script.
set -u

INTERVALO="${VIGILANTE_INTERVALO:-10}"
SILENCIO="${VIGILANTE_SILENCIO:-600}"
PAQUETE=mx.com.pierreposteria

reporte="${1:?Uso: bash tool/flujos_entorno_aislado.sh <reporte.json> flutter test <prueba.dart>... <opciones>}"
shift
comando=("$@")
archivos=()
for argumento in "${comando[@]}"; do
  case "$argumento" in
    *.dart) archivos+=("$argumento") ;;
  esac
done
if [ ${#archivos[@]} -eq 0 ]; then
  echo "Falta el comando de flutter test con al menos un archivo de pruebas." >&2
  exit 2
fi

# python3 en el CI; en Windows puede ser solo «python» (python3 abre la Tienda).
python=python3
"$python" -c "" 2> /dev/null || python=python
mkdir -p "$(dirname "$reporte")"
: > "$reporte"

# Lee un reporte JSON de flutter test. «pendientes»: los archivos sin una
# prueba terminada. «fallas»: cuántas pruebas fallaron.
leer() {
  "$python" - "$@" << 'PY'
import json
import sys

modo, parcial, archivos = sys.argv[1], sys.argv[2], sys.argv[3:]
suites, inicios, terminados, fallas = {}, {}, set(), 0
with open(parcial, encoding="utf-8", errors="replace") as reporte:
    for renglon in reporte:
        try:
            evento = json.loads(renglon)
        except ValueError:
            continue
        tipo = evento.get("type")
        if tipo == "suite":
            suites[evento["suite"]["id"]] = evento["suite"].get("path") or ""
        elif tipo == "testStart":
            inicios[evento["test"]["id"]] = evento["test"]
        elif tipo == "testDone" and not evento.get("hidden"):
            prueba = inicios.get(evento["testID"])
            if prueba is not None:
                ruta = suites.get(prueba.get("suiteID"), "").replace("\\", "/")
                terminados.add(ruta)
                if evento.get("result") != "success" and not evento.get("skipped"):
                    fallas += 1
if modo == "fallas":
    print(fallas)
else:
    for archivo in archivos:
        if not any(ruta.endswith(archivo) for ruta in terminados):
            print(archivo)
PY
}

# Corre el comando solo con los archivos de pruebas que recibe y deja su
# reporte en el primero. Imprime la salida mientras corre. Devuelve 124 si
# lo cortó.
correr() {
  local parcial="$1"
  shift
  local argumentos=() argumento archivo
  for argumento in "${comando[@]}"; do
    case "$argumento" in
      *.dart)
        for archivo in "$@"; do
          [ "$argumento" = "$archivo" ] && argumentos+=("$argumento")
        done
        ;;
      *) argumentos+=("$argumento") ;;
    esac
  done
  local bitacora
  bitacora=$(mktemp)
  "${argumentos[@]}" --file-reporter "json:$parcial" > "$bitacora" 2>&1 &
  local pid=$!
  tail -n +1 -f "$bitacora" &
  local pid_tail=$!
  local motivo=""
  while kill -0 "$pid" 2> /dev/null; do
    sleep "$INTERVALO"
    kill -0 "$pid" 2> /dev/null || break
    if adb shell dumpsys window 2> /dev/null | grep -q "Application Not Responding: $PAQUETE"; then
      motivo="la app quedó «isn't responding» al abrirse"
    elif [ $(($(date +%s) - $(stat -c %Y "$bitacora"))) -ge "$SILENCIO" ]; then
      motivo="flutter test pasó ${SILENCIO} s sin escribir nada"
    fi
    if [ -n "$motivo" ]; then
      kill "$pid" 2> /dev/null
      sleep 2
      kill -9 "$pid" 2> /dev/null
      break
    fi
  done
  wait "$pid"
  local codigo=$?
  sleep 1
  kill "$pid_tail" 2> /dev/null
  wait "$pid_tail" 2> /dev/null
  rm -f "$bitacora"
  if [ -n "$motivo" ]; then
    echo "::warning::Se cortó flutter test: $motivo (#375)."
    adb shell am force-stop "$PAQUETE" > /dev/null 2>&1
    return 124
  fi
  return "$codigo"
}

primero=$(mktemp)
correr "$primero" "${archivos[@]}"
codigo=$?
cat "$primero" >> "$reporte"

if [ "$codigo" -eq 124 ]; then
  mapfile -t faltan < <(leer pendientes "$primero" "${archivos[@]}" | tr -d '\r')
  fallas_antes=$(leer fallas "$primero" | tr -d '\r')
  if [ ${#faltan[@]} -gt 0 ]; then
    echo "Se vuelven a correr una vez: ${faltan[*]}"
    segundo=$(mktemp)
    correr "$segundo" "${faltan[@]}"
    codigo=$?
    cat "$segundo" >> "$reporte"
    rm -f "$segundo"
  else
    codigo=0
  fi
  # Una prueba que falló antes del corte hace fallar todo.
  if [ "$codigo" -eq 0 ] && [ "${fallas_antes:-0}" -gt 0 ]; then
    codigo=1
  fi
fi
rm -f "$primero"

if [ "$codigo" -eq 124 ]; then
  echo "::error::flutter test también se cortó en el reintento (#375)."
fi
exit "$codigo"
