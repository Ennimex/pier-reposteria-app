#!/usr/bin/env bash
# tool/comparar_rendimiento.sh — compara una medición con su línea base en
# tool/linea_base_rendimiento.json y falla si la rebasa (o si no hay línea
# base contra qué comparar):
#
#   bash tool/comparar_rendimiento.sh build/resultados/k6_rendimiento.json api_carga_normal
#   bash tool/comparar_rendimiento.sh build/resultados/arranque_en_frio.txt app_arranque_emulador
#   bash tool/comparar_rendimiento.sh build/app/outputs/flutter-apk/app-prod-release.apk app_peso_apk
#
# Qué se mide lo dice la línea base: el p95 del resumen de k6 (p95_ms), la
# mediana de las aperturas de tool/arranque_en_frio.sh (mediana_ms) o el peso
# del archivo (bytes). La regla también está en el JSON: un tiempo falla solo
# si sube más de 20 % Y además más de 25 ms (piso, para no fallar por el ruido
# de las computadoras de GitHub); el APK falla si crece más de 10 %.
#
# La cuenta la hace tool/resumen_pruebas.dart (comando comparar-rendimiento),
# que tiene sus pruebas en test/unitarias/ci/; también deja el resultado en el
# resumen de la corrida.
set -euo pipefail

medicion="$1"
escenario="$2"

dart run tool/resumen_pruebas.dart comparar-rendimiento "$medicion" "$escenario"
