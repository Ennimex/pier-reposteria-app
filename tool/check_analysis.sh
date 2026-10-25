#!/usr/bin/env bash
set -euo pipefail

baseline_errors=0
baseline_warnings=0
baseline_infos=151
output_file="$(mktemp)"
trap 'rm -f "$output_file"' EXIT

if flutter analyze --no-pub --no-fatal-infos --no-fatal-warnings \
  >"$output_file" 2>&1; then
  analyze_status=0
else
  analyze_status=$?
fi

cat "$output_file"

# Copia para el resumen de la corrida (tool/resumen_pruebas.dart analisis,
# #157); se guarda aunque el análisis falle, que es cuando más se necesita.
mkdir -p build/resultados
cp "$output_file" build/resultados/analisis.txt

if [ "$analyze_status" -ne 0 ]; then
  echo "::error::flutter analyze failed (exit $analyze_status)."
  exit "$analyze_status"
fi

# Cuenta errores, advertencias y avisos en los dos formatos de flutter
# analyze (Linux y Windows, #87) con tool/contar_analisis.sh, que imprime los
# tres números en un renglón.
conteo=$(bash "$(dirname "$0")/contar_analisis.sh" "$output_file")
read -r errors warnings infos <<<"$conteo"

# Basta con que uno de los tres pase su máximo para que el análisis falle.
excede_la_linea_base=false
if [ "$errors" -gt "$baseline_errors" ]; then
  excede_la_linea_base=true
fi
if [ "$warnings" -gt "$baseline_warnings" ]; then
  excede_la_linea_base=true
fi
if [ "$infos" -gt "$baseline_infos" ]; then
  excede_la_linea_base=true
fi

if [ "$excede_la_linea_base" = true ]; then
  echo "::error::Analysis exceeds baseline: errors=$errors/$baseline_errors, warnings=$warnings/$baseline_warnings, infos=$infos/$baseline_infos."
  exit 1
fi

echo "Static analysis is within baseline: errors=$errors, warnings=$warnings, infos=$infos."
