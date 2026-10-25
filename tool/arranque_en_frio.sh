#!/usr/bin/env bash
# tool/arranque_en_frio.sh — abre la app en frío varias veces en el emulador
# (o el celular) conectado por adb y guarda lo que reporta Android de cada
# apertura:
#
#   bash tool/arranque_en_frio.sh <paquete> <aperturas> <salida.txt>
#   bash tool/arranque_en_frio.sh mx.com.pierreposteria 5 build/resultados/arranque_en_frio.txt
#
# Antes de cada apertura cierra la app por completo (am force-stop), así
# Android la arranca desde cero (LaunchState: COLD). am start -W espera a que
# la app dibuje su primer cuadro e imprime cuánto tardó (TotalTime, en ms).
# La salida de cada apertura se agrega a <salida.txt>; de ahí
# tool/resumen_pruebas.dart (comandos arranque y comparar-rendimiento) saca la
# mediana. Falla si alguna apertura no mostró la ventana de la app
# (Status distinto de ok), con ese motivo.
set -euo pipefail

paquete="$1"
aperturas="$2"
salida="$3"
actividad="$paquete/.MainActivity"

mkdir -p "$(dirname "$salida")"
: > "$salida"

for apertura in $(seq 1 "$aperturas"); do
  # Cierra la app y espera un momento a que Android termine el proceso.
  adb shell am force-stop "$paquete"
  sleep 2

  # Abre la app y espera su primer cuadro; adb devuelve los renglones con
  # \r al final, que se quitan para leerlos.
  if ! resultado="$(adb shell am start -W -n "$actividad" | tr -d '\r')"; then
    echo "::error::adb no pudo abrir la app en la apertura $apertura."
    exit 1
  fi
  printf '%s\n\n' "$resultado" >> "$salida"
  echo "Apertura $apertura de $aperturas:"
  echo "$resultado"

  if ! printf '%s\n' "$resultado" | grep -q '^Status: ok$'; then
    echo "::error::La app no mostró su ventana en la apertura $apertura (am start -W); el detalle está en $salida."
    exit 1
  fi

  # Deja que termine de cargar su primera pantalla antes de cerrarla otra vez.
  sleep 3
done
