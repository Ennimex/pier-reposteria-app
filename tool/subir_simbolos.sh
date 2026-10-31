#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Sube a Sentry los símbolos de Dart de un build ofuscado (#224).
#
# Con --obfuscate, los nombres de las clases y funciones de Dart quedan
# renombrados dentro de libapp.so, y --split-debug-info guarda aparte sus
# símbolos: un app.android-<arquitectura>.symbols por arquitectura. Sentry los
# usa para leer los rastros de los errores, y el mapa de nombres
# (obfuscation.map.json, de --save-obfuscation-map) le devuelve su nombre a los
# tipos de excepción. Sin ellos, los errores de la versión publicada llegan
# ilegibles.
#
# uso: bash tool/subir_simbolos.sh <carpeta de --split-debug-info> [...]
# Cada carpeta trae sus .symbols y su obfuscation.map.json.
# Ambiente: SENTRY_AUTH_TOKEN (el secreto; nunca se imprime), SENTRY_ORG y
# SENTRY_PROJECT. Deja en el Summary el Debug ID de cada archivo y si Sentry
# terminó de procesarlo.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

VERSION_SENTRY_CLI=3.8.2
resumen="${GITHUB_STEP_SUMMARY:-/dev/null}"

if [ -z "${SENTRY_AUTH_TOKEN:-}" ]; then
  echo "::error::Falta el secreto SENTRY_AUTH_TOKEN: los símbolos no se subieron a Sentry."
  echo "### ❌ Falta el secreto SENTRY_AUTH_TOKEN: los símbolos no se subieron a Sentry" >> "$resumen"
  exit 1
fi

# sentry-cli con la versión fija, desde npm (que verifica la integridad del
# paquete). Se instala una vez por corrida.
dir_cli="${RUNNER_TEMP:-/tmp}/sentry-cli"
cli="$dir_cli/node_modules/.bin/sentry-cli"
if [ ! -x "$cli" ]; then
  npm install --prefix "$dir_cli" --no-save --no-audit --no-fund --loglevel=error \
    "@sentry/cli@$VERSION_SENTRY_CLI" > /dev/null
fi

for carpeta in "$@"; do
  mapa="$carpeta/obfuscation.map.json"
  shopt -s nullglob
  simbolos=("$carpeta"/*.symbols)
  shopt -u nullglob
  if [ ${#simbolos[@]} -eq 0 ] || [ ! -f "$mapa" ]; then
    echo "::error::En $carpeta faltan los .symbols o obfuscation.map.json."
    echo "### ❌ En \`$carpeta\` faltan los símbolos o el mapa de nombres" >> "$resumen"
    exit 1
  fi

  # --wait espera a que Sentry procese cada archivo y falla si alguno no sirve.
  bitacora="${RUNNER_TEMP:-/tmp}/subida-$(basename "$carpeta").txt"
  "$cli" debug-files upload --type elf --wait "$carpeta" | tee "$bitacora"

  echo "### 🔣 Símbolos en Sentry: \`$carpeta\`" >> "$resumen"
  for archivo in "${simbolos[@]}"; do
    "$cli" dart-symbol-map upload "$mapa" "$archivo"
    id=$("$cli" debug-files check "$archivo" | awk '/Debug ID:/ {print $NF; exit}')
    if grep -qi "OK.*$id" "$bitacora"; then
      estado="procesado"
    else
      estado="sin «OK» en la salida de sentry-cli: ver el paso"
    fi
    echo "- \`$(basename "$archivo")\` · Debug ID \`$id\` · $estado · con mapa de nombres" >> "$resumen"
  done
done
