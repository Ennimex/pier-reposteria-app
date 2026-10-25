#!/usr/bin/env bash
# tool/comparar_rendimiento.sh — compara el p95 de una corrida de k6 con su
# línea base en tool/linea_base_rendimiento.json y falla si subió más de 20 %
# (o si no hay línea base contra qué comparar):
#
#   bash tool/comparar_rendimiento.sh build/resultados/k6_rendimiento.json api_carga_normal
#
# La cuenta la hace tool/resumen_pruebas.dart (comando comparar-rendimiento),
# que tiene sus pruebas en test/unitarias/ci/; también deja el resultado en el
# resumen de la corrida.
set -euo pipefail

resumen_de_k6="$1"
escenario="$2"

dart run tool/resumen_pruebas.dart comparar-rendimiento "$resumen_de_k6" "$escenario"
