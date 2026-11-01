#!/usr/bin/env bash
# tool/arranque_alternado.sh — mide el arranque en frío de este cambio contra
# el de develop en el mismo emulador y en el mismo trabajo, para que la
# comparación dependa del cambio y no de qué tan rápida tocó la computadora
# de GitHub:
#
#   bash tool/arranque_alternado.sh <paquete> <rondas> <apk> <carpeta> [apk_develop]
#   bash tool/arranque_alternado.sh mx.com.pierreposteria 7 \
#     build/app/outputs/flutter-apk/app-prod-debug.apk build/resultados \
#     build/develop/app-prod-debug.apk
#
# Con el APK de develop: las dos apps tienen el mismo paquete y cada una está
# firmada con la llave de depuración de otra computadora, así que no caben a
# la vez. En cada ronda, por cada app: la desinstala, instala su APK, la abre
# una vez sin contarla (la primera apertura después de instalar es más lenta:
# Android todavía prepara la app) y la abre otra vez, esa sí contada. Las
# rondas impares empiezan por develop y las pares por este cambio, para que
# ninguna de las dos tenga siempre la ventaja (o la desventaja) de ir
# primero. Quedan <rondas> aperturas contadas de cada una.
#
# Sin el APK de develop (no hay uno guardado o ya expiró): instala este
# cambio, lo abre una vez sin contarla y <rondas> veces contadas; entonces
# decide la línea base fija.
#
# Cada apertura la hace tool/arranque_en_frio.sh (am force-stop y
# am start -W). En <carpeta> quedan, con la salida de am start -W de cada
# apertura:
#   arranque_en_frio.txt      las contadas de este cambio
#   arranque_develop.txt      las contadas de develop (solo con su APK)
#   arranque_descartadas.txt  las que no se contaron, cada una con su app y
#                             su ronda
# De ahí tool/resumen_pruebas.dart (comandos arranque y comparar-arranque)
# saca las medianas. Falla si una instalación o una apertura falla.
set -euo pipefail

paquete="$1"
rondas="$2"
apk="$3"
carpeta="$4"
apk_develop="${5:-}"
herramientas="$(dirname "$0")"

mkdir -p "$carpeta"
: > "$carpeta/arranque_en_frio.txt"
: > "$carpeta/arranque_descartadas.txt"
# Un arranque_develop.txt de una corrida anterior haría creer que hubo
# develop.
rm -f "$carpeta/arranque_develop.txt"

# tool/arranque_en_frio.sh vacía su archivo de salida en cada llamada: cada
# apertura va a este temporal y de ahí se agrega al archivo que le toca.
temporal="$(mktemp)"
trap 'rm -f "$temporal"' EXIT

# Instala <apk> desde cero. La app que haya puede estar firmada con otra
# llave (adb install -r fallaría), así que primero se quita; en la primera
# ronda no hay nada que quitar y adb uninstall falla sin importar.
instalar() {
  adb uninstall "$paquete" > /dev/null 2>&1 || true
  adb install "$1"
}

# Abre la app una vez y agrega lo que reportó Android a <archivo>; si la
# apertura falló, también la agrega (es la que explica el error) y falla.
abrir() {
  local codigo=0
  bash "$herramientas/arranque_en_frio.sh" "$paquete" 1 "$temporal" || codigo=$?
  cat "$temporal" >> "$1"
  if [ "$codigo" -ne 0 ]; then
    echo "Lo que reportó Android de esa apertura quedó al final de $1."
  fi
  return "$codigo"
}

# La primera apertura después de instalar: se guarda aparte, con su app y su
# ronda, y no cuenta para la mediana.
descartar() {
  echo "Descartada: $1, ronda $2"
  printf 'Descartada: %s, ronda %s\n' "$1" "$2" >> "$carpeta/arranque_descartadas.txt"
  abrir "$carpeta/arranque_descartadas.txt"
}

if [ -z "$apk_develop" ]; then
  echo "Sin APK de develop: $rondas aperturas contadas de este cambio; decide la línea base."
  instalar "$apk"
  descartar "este cambio" 1
  for ronda in $(seq 1 "$rondas"); do
    echo "Contada: este cambio, $ronda de $rondas"
    abrir "$carpeta/arranque_en_frio.txt"
  done
  exit 0
fi

: > "$carpeta/arranque_develop.txt"
for ronda in $(seq 1 "$rondas"); do
  if [ $((ronda % 2)) -eq 1 ]; then
    orden="develop cambio"
  else
    orden="cambio develop"
  fi
  for app in $orden; do
    if [ "$app" = develop ]; then
      instalar "$apk_develop"
      descartar develop "$ronda"
      echo "Contada: develop, ronda $ronda de $rondas"
      abrir "$carpeta/arranque_develop.txt"
    else
      instalar "$apk"
      descartar "este cambio" "$ronda"
      echo "Contada: este cambio, ronda $ronda de $rondas"
      abrir "$carpeta/arranque_en_frio.txt"
    fi
  done
done
