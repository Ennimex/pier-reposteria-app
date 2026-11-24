#!/usr/bin/env bash
# tool/rendimiento_celular/fluidez.sh — fluidez y arranque en frío de «Pier DEV» en modo profile, en el celular
# (#71, #324, #355, #384). Método, condiciones y umbrales: docs/pruebas-rendimiento-celular.md.
#
#   0. Compila los dos APK de Pier DEV en modo profile: el de integration_test/rendimiento/rendimiento_test.dart
#      (con la cuenta de prueba) y el de la app.
#   1. 3 corridas de la prueba con flutter drive. Cada corrida deja arranque, catalogo y
#      checkout.timeline_summary.json en build/; aquí se copian como <escena>_<n>.
#   2. 3 arranques en frío de la app con flutter run --trace-startup, cerrando la app antes de cada uno; se copia
#      build/start_up_info.json como start_up_info_<n>.json.
#
# Uso, desde la raíz del repositorio y con el código de la versión que se mide (el tag):
#   CUENTA_PRUEBA=<archivo fuera del repositorio> DISPOSITIVO=<serie de adb devices> \
#     bash tool/rendimiento_celular/fluidez.sh build/rendimiento_celular/<fecha>_<versión>
# y luego: python tool/rendimiento_celular/resumen_fluidez.py <la misma carpeta>
#
# La cuenta es la de prueba (la de los secretos de rendimiento-celular.yml): el correo en el primer renglón del
# archivo y la clave en el segundo. Nunca se imprime ni va en una línea de comandos: si flutter_tools se cae,
# escribe la suya en flutter_NN.log y en el enlace para reportar el error (#384). Pasa a Flutter con
# --dart-define-from-file, desde un JSON en una carpeta temporal fuera del repositorio que se borra al terminar,
# igual que los APK (el de la prueba lleva la cuenta compilada).
# APK compilados antes (#384): cuando compilan ellos, flutter drive y flutter run toman el paquete del manifiesto
# si todavía no hay un APK de Pier DEV en build/ (mx.com.pierreposteria, la «Pier» de la tienda); si un arranque
# falla, sus reintentos lo detienen y, si la instalación falla, lo desinstalan. Con --use-application-binary el
# paquete sale del APK. Además, el script instala cada APK antes de usarlo y se detiene si no puede (flutter,
# ante una instalación fallida, desinstala la app y la vuelve a instalar) o si desaparece del celular algún
# paquete de Pier que estaba al empezar.
# --keep-app-running: al terminar, flutter drive desinstala la app.
# --endless-trace-buffer: sin él la traza es un búfer circular que solo conserva lo último de cada escena (los
# 2.4 s finales de «arranque» y 84 de los 744 cuadros del catálogo). El primer cuadro del Inicio quedaba fuera, y
# los de la llegada de los datos entraban o no según lo que tardara el servidor (#341). Con él se mide la escena
# completa.
set -uo pipefail
export MSYS_NO_PATHCONV=1   # Git Bash en Windows: no convertir las rutas del celular

OUT="${1:?Uso: bash tool/rendimiento_celular/fluidez.sh <carpeta de salida>}"
: "${CUENTA_PRUEBA:?Falta CUENTA_PRUEBA (el archivo con la cuenta de prueba, fuera del repositorio)}"
: "${DISPOSITIVO:?Falta DISPOSITIVO (la serie que da adb devices)}"
API=https://pier-reposteria-backend.onrender.com/api
A="adb -s $DISPOSITIVO"
APK=build/app/outputs/flutter-apk/app-dev-profile.apk

alto() { echo "SE DETIENE: $*"; exit 1; }
# La ruta que entienden flutter y adb (programas de Windows con Git Bash, que no la convierte).
nativa() { if command -v cygpath > /dev/null; then cygpath -m "$1"; else printf '%s' "$1"; fi; }
minusculas() { tr '[:upper:]' '[:lower:]'; }   # Windows no distingue mayúsculas en las rutas
absoluta() { (cd "$(dirname "$1")" && printf '%s/%s' "$(pwd -P)" "$(basename "$1")") | minusculas; }
REPO=$(cd "$(git rev-parse --show-toplevel 2> /dev/null || pwd)" && pwd -P | minusculas)
dentro_del_repo() { case "$(absoluta "$1")/" in "$REPO"/*) return 0 ;; esac; return 1; }

[ -f "$CUENTA_PRUEBA" ] || alto "no existe el archivo CUENTA_PRUEBA"
dentro_del_repo "$CUENTA_PRUEBA" && alto "el archivo CUENTA_PRUEBA está dentro del repositorio: muévelo fuera"
U=$(sed -n 1p "$CUENTA_PRUEBA" | tr -d '\r\n')
C=$(sed -n 2p "$CUENTA_PRUEBA" | tr -d '\r\n')
[ -n "$U" ] && [ -n "$C" ] || alto "CUENTA_PRUEBA necesita el correo en el renglón 1 y la clave en el 2"
case "$U$C" in *[[:cntrl:]]*) alto "la cuenta de CUENTA_PRUEBA tiene caracteres de control" ;; esac

TMP=$(mktemp -d) || alto "no se pudo crear la carpeta temporal"
trap 'rm -rf "$TMP"' EXIT
trap 'exit 130' INT TERM
chmod 700 "$TMP"
dentro_del_repo "$TMP" && alto "la carpeta temporal ($TMP) está dentro del repositorio"
json() { printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'; }
(umask 077 && printf '{"USUARIO_PRUEBA": "%s", "CLAVE_PRUEBA": "%s"}\n' "$(json "$U")" "$(json "$C")" > "$TMP/cuenta.json")
mkdir -p "$OUT"

bateria() { $A shell dumpsys battery | tr -d '\r' | grep -E "level|temperature" | tr -s ' ' | tr '\n' ' '; }
al_frente() { $A shell dumpsys window | tr -d '\r' | grep -o 'mCurrentFocus=[^}]*'; }
paquetes_pier() { $A shell pm list packages | tr -d '\r' | grep -i pier | sort; }
revisar_paquetes() {
  [ "$($A get-state 2> /dev/null | tr -d '\r')" = device ] || alto "el celular $DISPOSITIVO no responde"
  local faltan
  faltan=$(comm -23 <(printf '%s\n' "$ANTES") <(paquetes_pier))
  [ -z "$faltan" ] || alto "ya no están instalados: $(echo $faltan)"
}
# adb install -r nunca desinstala: si falla, el script se detiene antes de que flutter lo intente a su manera.
instalar() {
  local salida
  salida=$($A install -r -t "$(nativa "$1")" 2>&1)
  if [ $? -ne 0 ] || printf '%s\n' "$salida" | grep -q '^Failure'; then
    alto "no se pudo instalar $(basename "$1"): $(printf '%s\n' "$salida" | tail -1)"
  fi
}

[ "$($A get-state 2> /dev/null | tr -d '\r')" = device ] || alto "el celular $DISPOSITIVO no responde"
ANTES=$(paquetes_pier)
echo "== paquetes de Pier al empezar: $(echo $ANTES)"

echo "== compilar $(date +%H:%M:%S)"
rm -f "$APK"
flutter build apk --profile --flavor dev --target=integration_test/rendimiento/rendimiento_test.dart \
  --dart-define=API_BASE_URL=$API --dart-define-from-file="$(nativa "$TMP/cuenta.json")" 2>&1 \
  | grep -F -v -e "$U" -e "$C" | grep -E "Built |Error|error:|FAILURE" | tail -5
[ -f "$APK" ] || alto "no se compiló el APK de la prueba"
mv "$APK" "$TMP/prueba.apk"
rm -f build/app/outputs/apk/dev/profile/app-dev-profile.apk   # la copia de Gradle, también con la cuenta
flutter build apk --profile --flavor dev --dart-define=API_BASE_URL=$API 2>&1 \
  | grep -E "Built |Error|error:|FAILURE" | tail -5
[ -f "$APK" ] || alto "no se compiló el APK de la app"
mv "$APK" "$TMP/app.apk"

revisar_paquetes
instalar "$TMP/prueba.apk"
for i in 1 2 3; do
  echo "== drive $i $(date +%H:%M:%S) · $(bateria) · $(al_frente)"
  rm -f build/arranque.timeline_summary.json build/catalogo.timeline_summary.json build/checkout.timeline_summary.json
  flutter drive --driver=test_driver/perf_driver.dart --target=integration_test/rendimiento/rendimiento_test.dart \
    --use-application-binary="$(nativa "$TMP/prueba.apk")" --profile --no-dds -d "$DISPOSITIVO" \
    --keep-app-running --endless-trace-buffer 2>&1 \
    | grep -F -v -e "$U" -e "$C" | grep -E "All tests passed|Some tests failed|\+[0-9]+|Error|error:|Exception" | tail -8
  for e in arranque catalogo checkout; do
    if [ -f "build/$e.timeline_summary.json" ]; then
      cp "build/$e.timeline_summary.json" "$OUT/${e}_$i.timeline_summary.json"
    else
      echo "FALTA $e $i"
    fi
  done
  revisar_paquetes
done

instalar "$TMP/app.apk"
for i in 1 2 3; do
  echo "== arranque en frío $i $(date +%H:%M:%S) · $(bateria)"
  $A shell am force-stop mx.com.pierreposteria.dev
  sleep 3
  rm -f build/start_up_info.json
  flutter run --use-application-binary="$(nativa "$TMP/app.apk")" --profile --trace-startup -d "$DISPOSITIVO" 2>&1 \
    | grep -E "start_up_info|Error|error:" | tail -4
  if [ -f build/start_up_info.json ]; then
    cp build/start_up_info.json "$OUT/start_up_info_$i.json"
  else
    echo "FALTA start_up_info $i"
  fi
  revisar_paquetes
done
echo "== fin $(date +%H:%M:%S) · $(bateria) · paquetes de Pier: $(echo $(paquetes_pier))"
