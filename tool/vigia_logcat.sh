#!/usr/bin/env bash
# DIAGNÓSTICO TEMPORAL: esta rama no se mezcla.
#
# Se deja corriendo antes de encender el emulador. Arranca el servidor de adb
# y, cada vez que un emulador queda en línea, guarda:
#   · vigia_servicios_N.txt: durante el primer minuto, cada segundo, el
#     tiempo encendido, sys.boot_completed, si están publicados los servicios
#     «input», «package» y «activity», y los procesos del sistema con el
#     tiempo que llevan.
#   · vigia_logcat_N.txt: todo el logcat, desde lo que ya había en el búfer
#     hasta que el emulador se apaga.
# N cuenta los emuladores que ha visto (uno por sesión).
#
# Uso: nohup bash tool/vigia_logcat.sh > build/resultados/vigia.txt 2>&1 &
ADB="${ANDROID_HOME:-/usr/local/lib/android/sdk}/platform-tools/adb"
R=build/resultados
mkdir -p "$R"

hora() { date -u +%H:%M:%S.%N | cut -c1-12; }

"$ADB" start-server
echo "[$(hora)] servidor de adb listo"
n=0
while true; do
  "$ADB" wait-for-device > /dev/null 2>&1
  n=$((n + 1))
  echo "[$(hora)] emulador en línea (vez $n)"
  (
    for _ in $(seq 1 60); do
      echo "$(hora) | $("$ADB" shell "cut -d' ' -f1 /proc/uptime; getprop sys.boot_completed; service check input; service check package; service check activity; ps -A -o PID,ETIME,NAME | grep -E 'system_server|zygote64|surfaceflinger|servicemanager'" 2>&1 | tr -d '\r' | tr '\n' '|')"
      sleep 1
    done
  ) > "$R/vigia_servicios_$n.txt" 2>&1 &
  "$ADB" logcat -v threadtime -v year -b main,system,crash,events > "$R/vigia_logcat_$n.txt" 2>&1
  echo "[$(hora)] logcat terminó (código $?)"
  sleep 2
done
