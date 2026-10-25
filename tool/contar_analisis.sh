#!/usr/bin/env bash
# Cuenta los errores, advertencias y avisos de una salida de flutter analyze
# (el archivo del primer argumento) e imprime los tres números en un renglón:
#
#   bash tool/contar_analisis.sh build/resultados/analisis.txt   # → 0 0 55
#
# Lo usa tool/check_analysis.sh para compararlos con la línea base.
# flutter analyze separa los campos con «•» en Linux (CI) y con «-» en
# Windows: se cuentan ambos formatos (#87). Se cuenta con awk porque termina
# bien aunque no encuentre ninguno; grep -c terminaba con error al contar 0.
set -euo pipefail

salida_de_analyze="$1"

awk '
  /^[[:space:]]*error (-|•) /   { errores++ }
  /^[[:space:]]*warning (-|•) / { advertencias++ }
  /^[[:space:]]*info (-|•) /    { avisos++ }
  END { print errores + 0, advertencias + 0, avisos + 0 }
' "$salida_de_analyze"
