#!/usr/bin/env bash
# DIAGNÓSTICO TEMPORAL: esta rama no se mezcla.
#
# Corre el comando que recibe (los tres flujos del entorno aislado, tal como
# los corre el job de integración) y guarda lo que hace falta para saber por
# qué a veces la app recién instalada nunca conecta con flutter test y el job
# se queda esperando hasta que GitHub lo cancela.
#
# Dos modos:
#   · completa: mientras corre el comando guarda el reloj del emulador
#     (reloj.txt), todo el logcat (logcat*.txt) y, cada 15 s, el estado de la
#     computadora y del emulador (estado.txt).
#   · ligera: no habla con el emulador hasta que el comando termina o se da
#     por colgado, para no alterar lo que se quiere observar.
# En los dos, al final (final_*) y al darlo por colgado (colgado_*): logcat
# de lo que quede en el búfer, procesos del sistema con el tiempo que llevan
# (si system_server lleva menos que el emulador, Android se reinició), los
# registros de caídas de DropBox y una captura de pantalla.
# salida.txt trae la salida del comando, cada renglón con su hora (UTC).
# Si el comando pasa 10 min sin escribir nada, lo da por colgado y lo termina
# con el código 124.
#
# Uso: bash tool/diagnostico_flujos.sh <android> <completa|ligera> <comando...>
set -u

ANDROID="${1:?falta la versión de Android}"
MODO="${2:?falta el modo: completa o ligera}"
shift 2
# DIAG_DIR: carpeta de esta sesión. DIAG_ESPERA: segundos de espera antes del
# comando, para que la app arranque más tarde respecto al emulador.
R="${DIAG_DIR:-build/resultados}"
ESPERA="${DIAG_ESPERA:-0}"
PAQUETE=mx.com.pierreposteria
SILENCIO_MAXIMO=600
DURACION_MAXIMA=1800
mkdir -p "$R"
T0=$(date +%s)
PIDS_DE_FONDO=""

transcurrido() { echo $(( $(date +%s) - T0 )); }
marca() { echo "[$(date -u +%H:%M:%S) +$(transcurrido)s] $*"; }

# Lo que se puede saber del emulador sin haberlo observado antes.
guardar_sistema() {
  prefijo="$1"
  {
    echo "===== $(date -u '+%F %T') +$(transcurrido)s"
    echo "--- hora del emulador y tiempo encendido"
    adb shell "date -u '+%F %T'; cat /proc/uptime"
    echo "--- procesos del sistema y tiempo que llevan"
    adb shell "ps -A -o PID,PPID,ETIME,NAME | grep -E 'ETIME|zygote|system_server|surfaceflinger|servicemanager|adbd|logd|$PAQUETE'"
    echo "--- propiedades de arranque"
    adb shell "getprop | grep -E 'boot|init.svc.zygote|init.svc.surfaceflinger|init.svc.servicemanager|init.svc.adbd|sys.sysctl|ro.runtime'"
    echo "--- foco y pantalla"
    adb shell "dumpsys window | grep -E 'mCurrentFocus|mFocusedApp'; dumpsys power | grep -E 'mWakefulness=|Display Power'"
    echo "--- espacio y memoria"
    adb shell "df -h /data; cat /proc/meminfo | head -5"
    echo "--- puertos reenviados"
    adb forward --list
  } > "$R/${prefijo}_sistema.txt" 2>&1
  {
    adb shell dumpsys dropbox
    for etiqueta in SYSTEM_BOOT SYSTEM_RESTART system_server_watchdog system_server_crash system_server_anr \
      system_server_wtf SYSTEM_TOMBSTONE data_app_crash data_app_native_crash data_app_anr system_app_crash \
      system_app_anr; do
      echo "########## $etiqueta"
      adb shell dumpsys dropbox --print "$etiqueta" | head -n 400
    done
  } > "$R/${prefijo}_dropbox.txt" 2>&1
  adb logcat -d -v threadtime -v year -b main,system,crash,events,radio > "$R/${prefijo}_logcat.txt" 2>&1
  adb logcat -d -v threadtime -v year -b kernel > "$R/${prefijo}_logcat_kernel.txt" 2>&1
  adb exec-out screencap -p > "$R/${prefijo}_pantalla.png" 2> /dev/null
}

guardar_estado_colgado() {
  {
    echo "===== $(date -u '+%F %T') +$(transcurrido)s: $1"
    echo "--- árbol de procesos de la computadora"
    ps -eo pid,ppid,etimes,stat,args --forest | grep -v -E "\]$" | cut -c1-260
    echo "--- puertos en escucha"
    ss -ltnp | cut -c1-200
    echo "--- ¿responde cada puerto reenviado?"
    for puerto in $(adb forward --list | sed -n 's/^[^ ]* tcp:\([0-9]*\) tcp:.*$/\1/p'); do
      echo "GET http://127.0.0.1:$puerto/ -> $(curl -s -m 5 -o /dev/null -w '%{http_code}' "http://127.0.0.1:$puerto/" 2>&1)"
    done
  } > "$R/colgado.txt" 2>&1
  guardar_sistema colgado
  adb shell dumpsys activity activities > "$R/colgado_actividades.txt" 2>&1
  adb shell dumpsys activity processes > "$R/colgado_procesos.txt" 2>&1
}

marca "Android $ANDROID, modo $MODO"
if [ "$MODO" = completa ]; then
  {
    echo "screen_off_timeout=$(adb shell settings get system screen_off_timeout 2>&1)"
    echo "stay_on_while_plugged_in=$(adb shell settings get global stay_on_while_plugged_in 2>&1)"
    echo "hora_computadora=$(date -u '+%F %T')"
    echo "hora_emulador=$(adb shell "date -u '+%F %T'" 2>&1)"
    echo "encendido=$(adb shell cat /proc/uptime 2>&1)"
    echo "--- procesos del sistema y tiempo que llevan"
    adb shell "ps -A -o PID,PPID,ETIME,NAME | grep -E 'ETIME|zygote|system_server|surfaceflinger|servicemanager|adbd|logd'" 2>&1
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
  PIDS_DE_FONDO="$PIDS_DE_FONDO $!"

  # Todo el logcat: primero lo que ya había en el búfer y después lo nuevo.
  adb logcat -v threadtime -v year -b main,system,crash,events,radio > "$R/logcat.txt" 2>&1 &
  PIDS_DE_FONDO="$PIDS_DE_FONDO $!"
  adb logcat -v threadtime -v year -b kernel > "$R/logcat_kernel.txt" 2>&1 &
  PIDS_DE_FONDO="$PIDS_DE_FONDO $!"

  # El estado de la computadora y del emulador.
  (
    while true; do
      echo "===== $(date -u '+%F %T') +$(transcurrido)s"
      echo "--- procesos de la computadora (adb, dart, flutter)"
      ps -eo pid,ppid,etimes,args | grep -E "adb|dart|flutter" | grep -v -E "grep|diagnostico_flujos" | cut -c1-240
      echo "--- puertos reenviados"
      adb forward --list 2>&1
      echo "--- foco, pantalla, procesos del sistema y de la app"
      adb shell "dumpsys window | grep -E 'mCurrentFocus|mFocusedApp'; dumpsys power | grep -E 'mWakefulness=|Display Power'; ps -A -o PID,PPID,ETIME,NAME | grep -E 'ETIME|zygote|system_server|$PAQUETE'" 2>&1 | tr -d '\r'
      sleep 15
    done
  ) > "$R/estado.txt" 2>&1 &
  PIDS_DE_FONDO="$PIDS_DE_FONDO $!"
fi

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
if [ "$ESPERA" -gt 0 ]; then
  marca "espera de ${ESPERA}s antes del comando"
  sleep "$ESPERA"
fi
# DIAG_ENCENDIDO_MINIMO: espera hasta que el emulador lleve encendido al
# menos esos segundos (como sin la caché de Gradle, que tardaba 5-7 min).
ENCENDIDO_MINIMO="${DIAG_ENCENDIDO_MINIMO:-0}"
if [ "$ENCENDIDO_MINIMO" -gt 0 ]; then
  encendido=$(adb shell cut -d. -f1 /proc/uptime | tr -d '\r ')
  if [ "${encendido:-0}" -lt "$ENCENDIDO_MINIMO" ]; then
    marca "el emulador lleva ${encendido}s encendido; espera $((ENCENDIDO_MINIMO - encendido))s"
    sleep $((ENCENDIDO_MINIMO - encendido))
  fi
  marca "encendido: $(adb shell cut -d' ' -f1 /proc/uptime | tr -d '\r')s"
fi
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

guardar_sistema final
echo "----- sistema al terminar"
cut -c1-200 "$R/final_sistema.txt"
echo "----- DropBox al terminar (sin los de strictmode)"
grep -v -E "strictmode|^$" "$R/final_dropbox.txt" | head -n 60 | cut -c1-200
bash tool/entorno_pruebas.sh logs > "$R/entorno_logs.txt" 2>&1
# shellcheck disable=SC2086
kill $PIDS_DE_FONDO 2> /dev/null
sleep 1
marca "evidencia guardada: $(ls "$R" | tr '\n' ' ')"
exit "$CODIGO"
