#!/usr/bin/env bash
# Pruebas de aceptación de firma y ambientes (#53), para repetirlas en cada
# liberación. Comprueba los criterios de:
#   #11  el APK de release lleva la firma del equipo y no hay llaves en Git;
#   #12  los tres ambientes se compilan como apps distintas que conviven;
#   #13  cada ambiente apunta a su backend (prueba unitaria de ApiConstants).
#
# Uso, desde la raíz del repositorio:
#   bash tool/verificar_ambientes.sh             # compila y revisa los APK
#   bash tool/verificar_ambientes.sh --instalar  # además los instala en el
#                                                # dispositivo conectado (adb)
#
# Requiere Flutter y el SDK de Android (apksigner y aapt2 de build-tools).
# Sin android/key.properties la revisión de la firma se omite: en esa
# computadora el release se firma con la llave de depuración, a propósito
# (ver README, «Firma de release»).
set -euo pipefail

cd "$(dirname "$0")/.."

instalar=false
[ "${1:-}" = "--instalar" ] && instalar=true

fallas=0
ok() { echo "  ✓ $1"; }
falla() { echo "  ✗ $1"; fallas=$((fallas + 1)); }

# build-tools más reciente del SDK: de ahí salen apksigner y aapt2.
sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
for candidato in "$sdk" "${LOCALAPPDATA:-}/Android/sdk" "$HOME/Android/Sdk" \
  "$HOME/Library/Android/sdk"; do
  if [ -n "$candidato" ] && [ -d "$candidato/build-tools" ]; then
    sdk="$candidato"
    break
  fi
done
build_tools="$(ls -d "$sdk"/build-tools/* 2>/dev/null | sort -V | tail -1)"
if [ -z "$build_tools" ]; then
  echo "No encontré build-tools del SDK de Android; define ANDROID_HOME." >&2
  exit 1
fi
apksigner="$build_tools/apksigner"
[ -f "$apksigner.bat" ] && apksigner="$apksigner.bat"
aapt2="$build_tools/aapt2"
[ -f "$aapt2.exe" ] && aapt2="$aapt2.exe"

apks=build/app/outputs/flutter-apk

echo "== #11 Firma de release"
# awk termina bien aunque no encuentre nada (grep terminaba con error).
llaves_en_git="$(git ls-files | awk '/jks|keystore|key\.properties/')"
if [ -z "$llaves_en_git" ]; then
  ok "Git no contiene keystores ni key.properties"
else
  falla "Git contiene archivos de llaves: $llaves_en_git"
fi

if [ -f android/key.properties ]; then
  flutter build apk --release >/dev/null
  certificado="$("$apksigner" verify --print-certs "$apks/app-prod-release.apk" |
    grep -m1 'certificate DN' | sed 's/.*certificate DN: //')"
  if [ -z "$certificado" ]; then
    falla "apksigner no pudo leer la firma de app-prod-release.apk"
  elif echo "$certificado" | grep -q 'Android Debug'; then
    falla "el release está firmado con la llave de depuración ($certificado)"
  else
    ok "release firmado con la llave del equipo: $certificado"
  fi
else
  echo "  - omitido: no existe android/key.properties en esta computadora"
fi

echo "== #12 Tres ambientes que conviven"
for flavor in prod staging dev; do
  case "$flavor" in
    prod) esperado="mx.com.pierreposteria" ;;
    *) esperado="mx.com.pierreposteria.$flavor" ;;
  esac
  flutter build apk --debug --flavor "$flavor" >/dev/null
  apk="$apks/app-$flavor-debug.apk"
  paquete="$("$aapt2" dump badging "$apk" | sed -n "s/^package: name='\([^']*\)'.*/\1/p")"
  nombre="$("$aapt2" dump badging "$apk" | sed -n "s/^application-label:'\(.*\)'$/\1/p")"
  if [ "$paquete" = "$esperado" ]; then
    ok "$flavor: $paquete («$nombre»)"
  else
    falla "$flavor: el paquete es '$paquete' y debía ser '$esperado'"
  fi
  if $instalar; then
    adb install -r "$apk" >/dev/null
  fi
done

if $instalar; then
  instaladas="$(adb shell pm list packages | tr -d '\r')"
  for paquete in mx.com.pierreposteria mx.com.pierreposteria.staging \
    mx.com.pierreposteria.dev; do
    if echo "$instaladas" | grep -qx "package:$paquete"; then
      ok "instalada en el dispositivo: $paquete"
    else
      falla "no quedó instalada en el dispositivo: $paquete"
    fi
  done
fi

echo "== #13 Backend por ambiente"
if flutter test test/unitarias/comun/ambiente_test.dart >/dev/null; then
  ok "ApiConstants resuelve el backend de cada ambiente"
else
  falla "falló test/unitarias/comun/ambiente_test.dart"
fi

echo
if [ "$fallas" -eq 0 ]; then
  echo "Todo en orden."
else
  echo "$fallas comprobación(es) fallaron."
  exit 1
fi
