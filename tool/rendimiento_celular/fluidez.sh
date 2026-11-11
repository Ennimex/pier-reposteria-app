#!/usr/bin/env bash
# tool/rendimiento_celular/fluidez.sh — fluidez y arranque en frío de «Pier DEV» en modo profile, en el celular
# (#71, #324, #355). Método, condiciones y umbrales: docs/pruebas-rendimiento-celular.md.
#
#   1. 3 corridas de integration_test/rendimiento/rendimiento_test.dart con flutter drive. Cada corrida deja
#      arranque, catalogo y checkout.timeline_summary.json en build/; aquí se copian como <escena>_<n>.
#   2. 3 arranques en frío con flutter run --trace-startup, cerrando la app antes de cada uno; se copia
#      build/start_up_info.json como start_up_info_<n>.json.
#
# Uso, desde la raíz del repositorio y con el código de la versión que se mide (el tag):
#   USUARIO_PRUEBA=... CLAVE_PRUEBA=... DISPOSITIVO=<serie de adb devices> \
#     bash tool/rendimiento_celular/fluidez.sh build/rendimiento_celular/<fecha>_<versión>
# y luego: python tool/rendimiento_celular/resumen_fluidez.py <la misma carpeta>
#
# La cuenta es la de prueba (la de los secretos de rendimiento-celular.yml); nunca se imprime.
# --keep-app-running: al terminar, flutter drive desinstala la app, y en un worktree nuevo la primera vez toma
# el paquete del manifiesto (mx.com.pierreposteria, la app instalada de la tienda) en vez del de Pier DEV.
set -uo pipefail
export MSYS_NO_PATHCONV=1   # Git Bash en Windows: no convertir las rutas del celular

OUT="${1:?Uso: bash tool/rendimiento_celular/fluidez.sh <carpeta de salida>}"
: "${USUARIO_PRUEBA:?Falta USUARIO_PRUEBA (la cuenta de prueba)}"
: "${CLAVE_PRUEBA:?Falta CLAVE_PRUEBA}"
: "${DISPOSITIVO:?Falta DISPOSITIVO (la serie que da adb devices)}"
API=https://pier-reposteria-backend.onrender.com/api
U=$(printf '%s' "$USUARIO_PRUEBA" | tr -d '\r\n')
C=$(printf '%s' "$CLAVE_PRUEBA" | tr -d '\r\n')
A="adb -s $DISPOSITIVO"
mkdir -p "$OUT"

bateria() { $A shell dumpsys battery | tr -d '\r' | grep -E "level|temperature" | tr -s ' ' | tr '\n' ' '; }
al_frente() { $A shell dumpsys window | tr -d '\r' | grep -o 'mCurrentFocus=[^}]*'; }

for i in 1 2 3; do
  echo "== drive $i $(date +%H:%M:%S) · $(bateria) · $(al_frente)"
  rm -f build/arranque.timeline_summary.json build/catalogo.timeline_summary.json build/checkout.timeline_summary.json
  flutter drive --driver=test_driver/perf_driver.dart --target=integration_test/rendimiento/rendimiento_test.dart \
    --profile --no-dds --flavor dev -d "$DISPOSITIVO" --keep-app-running \
    --dart-define=API_BASE_URL=$API --dart-define=USUARIO_PRUEBA="$U" --dart-define=CLAVE_PRUEBA="$C" 2>&1 \
    | grep -F -v -e "$U" -e "$C" | grep -E "All tests passed|Some tests failed|\+[0-9]+|Error|error:|Exception" | tail -8
  for e in arranque catalogo checkout; do
    if [ -f "build/$e.timeline_summary.json" ]; then
      cp "build/$e.timeline_summary.json" "$OUT/${e}_$i.timeline_summary.json"
    else
      echo "FALTA $e $i"
    fi
  done
  echo "paquetes de Pier instalados: $($A shell pm list packages | tr -d '\r' | grep -c pierreposteria)"
done

for i in 1 2 3; do
  echo "== arranque en frío $i $(date +%H:%M:%S) · $(bateria)"
  $A shell am force-stop mx.com.pierreposteria.dev
  sleep 3
  rm -f build/start_up_info.json
  flutter run --profile --trace-startup --flavor dev -d "$DISPOSITIVO" --dart-define=API_BASE_URL=$API 2>&1 \
    | grep -E "start_up_info|Error|error:" | tail -4
  if [ -f build/start_up_info.json ]; then
    cp build/start_up_info.json "$OUT/start_up_info_$i.json"
  else
    echo "FALTA start_up_info $i"
  fi
done
echo "== fin $(date +%H:%M:%S) · $(bateria)"
