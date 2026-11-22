#!/usr/bin/env bash
# DIAGNÓSTICO TEMPORAL: esta rama no se mezcla.
#
# Corre el comando que recibe (los tres flujos del entorno aislado, tal como
# los corre el job de integración) y guarda, además, lo que hace falta para
# saber por qué a veces la app recién instalada nunca conecta con flutter test
# y el job se queda esperando hasta que GitHub lo cancela:
#   · ajustes.txt: ajustes del emulador que podrían influir (apagado de
#     pantalla, hora automática, búferes de logcat) y su hora al empezar.
#   · reloj.txt: cada 3 s, la hora de la computadora, la del emulador, su
#     tiempo encendido y el último renglón de logcat (de ahí saca flutter la
#     marca para leer logcat «desde ahora»).
#   · logcat.txt (principal, sistema, caídas, eventos y radio),
#     logcat_kernel.txt y logcat_por_omision.txt (lo mismo que lee flutter),
#     desde que empieza el paso.
#   · estado.txt: cada 15 s, los procesos de adb y dart en la computadora,
#     los puertos reenviados, la ventana con el foco, si la pantalla está
#     encendida y el proceso de la app.
#   · salida.txt: la salida del comando, cada renglón con su hora (UTC).
# Si el comando pasa 10 min sin escribir nada, lo da por colgado: guarda el
# estado de ese momento (colgado*.txt y una captura de pantalla) y lo termina
# con el código 124.
#
# Uso: bash tool/diagnostico_flujos.sh <android> <comando...>
set -u

ANDROID="${1:?falta la versión de Android}"
shift
R=build/resultados
PAQUETE=mx.com.pierreposteria
SILENCIO_MAXIMO=600
DURACION_MAXIMA=1800
mkdir -p "$R"
T0=$(date +%s)

transcurrido() { echo $(( $(date +%s) - T0 )); }
marca() { echo "[$(date -u +%H:%M:%S) +$(transcurrido)s] $*"; }

marca "Android $ANDROID: ajustes del emulador"
{
  echo "screen_off_timeout=$(adb shell settings get system screen_off_timeout 2>&1)"
  echo "stay_on_while_plugged_in=$(adb shell settings get global stay_on_while_plugged_in 2>&1)"
  echo "auto_time=$(adb shell settings get global auto_time 2>&1)"
  echo "auto_time_zone=$(adb shell settings get global auto_time_zone 2>&1)"
  echo "zona=$(adb shell getprop persist.sys.timezone 2>&1)"
  echo "boot_completed=$(adb shell getprop sys.boot_completed 2>&1)"
  echo "ro.logd.kernel=$(adb shell getprop ro.logd.kernel 2>&1)"
  echo "ro.debuggable=$(adb shell getprop ro.debuggable 2>&1)"
  echo "usuario_de_adb=$(adb shell id 2>&1)"
  echo "hora_computadora=$(date -u '+%F %T')"
  echo "hora_emulador=$(adb shell "date -u '+%F %T'" 2>&1)"
  echo "encendido=$(adb shell cat /proc/uptime 2>&1)"
  echo "pantalla=$(adb shell "dumpsys power | grep -E 'mWakefulness=|Display Power'" 2>&1 | tr '\n' ' ')"
  echo "--- búferes de logcat"
  adb shell logcat -g 2>&1
} | tr -d '\r' | tee "$R/ajustes.txt"

# El reloj del emulador contra el de la computadora.
(
  while true; do
    emulador=$(adb shell "date -u '+%F %T'; cut -d' ' -f1 /proc/uptime; logcat -v time -t 1 | tail -n 1 | cut -c1-110" 2>&1 | tr -d '\r' | tr '\n' '|')
    echo "$(date -u '+%F %T') | $emulador"
    sleep 3
  done
) > "$R/reloj.txt" 2>&1 &
PID_RELOJ=$!

# Todo el logcat: primero lo que ya había en el búfer y después lo nuevo.
adb logcat -v threadtime -v year -b main,system,crash,events,radio > "$R/logcat.txt" 2>&1 &
PID_LOGCAT=$!
adb logcat -v threadtime -v year -b kernel > "$R/logcat_kernel.txt" 2>&1 &
PID_LOGCAT_KERNEL=$!
adb logcat -v time > "$R/logcat_por_omision.txt" 2>&1 &
PID_LOGCAT_OMISION=$!

# El estado de la computadora y del emulador.
(
  while true; do
    echo "===== $(date -u '+%F %T') +$(transcurrido)s"
    echo "--- procesos de la computadora (adb, dart, flutter)"
    ps -eo pid,ppid,etimes,args | grep -E "adb|dart|flutter" | grep -v -E "grep|diagnostico_flujos" | cut -c1-240
    echo "--- puertos reenviados"
    adb forward --list 2>&1
    echo "--- foco, pantalla y proceso de la app"
    adb shell "dumpsys window | grep -E 'mCurrentFocus|mFocusedApp'; dumpsys power | grep -E 'mWakefulness=|Display Power'; ps -A | grep -E '$PAQUETE|PID'" 2>&1 | tr -d '\r'
    sleep 15
  done
) > "$R/estado.txt" 2>&1 &
PID_ESTADO=$!

guardar_estado_colgado() {
  {
    echo "===== $(date -u '+%F %T') +$(transcurrido)s: $1"
    echo "--- árbol de procesos de la computadora"
    ps -eo pid,ppid,etimes,stat,args --forest | grep -v -E "\]$" | cut -c1-260
    echo "--- puertos reenviados"
    adb forward --list
    echo "--- puertos en escucha"
    ss -ltnp | cut -c1-200
    echo "--- hora de la computadora y del emulador"
    date -u '+%F %T'
    adb shell "date -u '+%F %T'; cat /proc/uptime"
    echo "--- proceso de la app"
    adb shell "ps -A | grep -E '$PAQUETE|PID'"
    echo "--- ¿responde cada puerto reenviado?"
    for puerto in $(adb forward --list | sed -n 's/^[^ ]* tcp:\([0-9]*\) tcp:.*$/\1/p'); do
      echo "GET http://127.0.0.1:$puerto/ -> $(curl -s -m 5 -o /dev/null -w '%{http_code}' "http://127.0.0.1:$puerto/" 2>&1)"
    done
  } > "$R/colgado.txt" 2>&1
  adb exec-out screencap -p > "$R/colgado_pantalla.png" 2> /dev/null
  adb shell dumpsys activity activities > "$R/colgado_actividades.txt" 2>&1
  adb shell dumpsys activity processes > "$R/colgado_procesos.txt" 2>&1
  adb shell dumpsys power > "$R/colgado_energia.txt" 2>&1
}

# El comando escribe en una tubería con nombre y otro proceso le pone la hora
# a cada renglón: así $! es el comando mismo y se le puede terminar.
TUBO=$(mktemp -u)
mkfifo "$TUBO"
python3 -u -c '
import sys, time
for renglon in sys.stdin.buffer:
    sys.stdout.buffer.write(time.strftime("%H:%M:%S ", time.gmtime()).encode() + renglon)
    sys.stdout.buffer.flush()
' < "$TUBO" > "$R/salida.txt" &
PID_HORA=$!
marca "comando: $*"
"$@" > "$TUBO" 2>&1 &
PID_COMANDO=$!

CODIGO=""
ULTIMO_AVISO=0
while kill -0 "$PID_COMANDO" 2> /dev/null; do
  sleep 5
  ahora=$(date +%s)
  ultima=$(stat -c %Y "$R/salida.txt" 2> /dev/null || echo "$ahora")
  reporte=$(stat -c %Y "$R"/flujo_entorno_aislado_android_*.json 2> /dev/null | sort -n | tail -n 1)
  if [ -n "$reporte" ] && [ "$reporte" -gt "$ultima" ]; then ultima=$reporte; fi
  silencio=$(( ahora - ultima ))
  if [ $(( ahora - ULTIMO_AVISO )) -ge 60 ]; then
    ULTIMO_AVISO=$ahora
    marca "en curso; $(wc -l < "$R/salida.txt") renglones de salida; el último hace ${silencio}s: $(tail -n 1 "$R/salida.txt" | cut -c1-150)"
  fi
  motivo=""
  if [ "$silencio" -gt "$SILENCIO_MAXIMO" ]; then motivo="sin salida desde hace ${silencio}s"; fi
  if [ "$(transcurrido)" -gt "$DURACION_MAXIMA" ]; then motivo="más de ${DURACION_MAXIMA}s en total"; fi
  if [ -n "$motivo" ]; then
    marca "COLGADO: $motivo"
    guardar_estado_colgado "$motivo"
    kill "$PID_COMANDO" 2> /dev/null
    sleep 10
    kill -9 "$PID_COMANDO" 2> /dev/null
    CODIGO=124
    break
  fi
done
wait "$PID_COMANDO"
CODIGO_DEL_COMANDO=$?
if [ -z "$CODIGO" ]; then CODIGO=$CODIGO_DEL_COMANDO; fi
marca "el comando terminó con código $CODIGO (wait dio $CODIGO_DEL_COMANDO)"
sleep 2
kill "$PID_HORA" 2> /dev/null
rm -f "$TUBO"

echo "----- últimos renglones de la salida"
tail -n 40 "$R/salida.txt" | cut -c1-300
echo "----- renglones de la prueba en la salida"
grep -n -E " test [0-9]+: |VM Service|Dart Development Service|Installing build|Built build|am start|logcat -v time" "$R/salida.txt" | cut -c1-260 | tail -n 150

adb exec-out screencap -p > "$R/final_pantalla.png" 2> /dev/null
bash tool/entorno_pruebas.sh logs > "$R/entorno_logs.txt" 2>&1
kill "$PID_RELOJ" "$PID_LOGCAT" "$PID_LOGCAT_KERNEL" "$PID_LOGCAT_OMISION" "$PID_ESTADO" 2> /dev/null
sleep 1
marca "evidencia guardada: $(ls "$R" | tr '\n' ' ')"
exit "$CODIGO"
