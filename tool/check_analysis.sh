#!/usr/bin/env bash
set -euo pipefail

baseline_errors=0
baseline_warnings=1
baseline_infos=648
output_file="$(mktemp)"
trap 'rm -f "$output_file"' EXIT

if flutter analyze --no-pub --no-fatal-infos --no-fatal-warnings \
  >"$output_file" 2>&1; then
  analyze_status=0
else
  analyze_status=$?
fi

cat "$output_file"

if [ "$analyze_status" -ne 0 ]; then
  echo "::error::flutter analyze failed (exit $analyze_status)."
  exit "$analyze_status"
fi

# flutter analyze separa los campos con «•» en Linux (CI) y con «-» en
# Windows: se cuentan ambos formatos.
errors=$(grep -Ec '^[[:space:]]*error (-|•) ' "$output_file" || true)
warnings=$(grep -Ec '^[[:space:]]*warning (-|•) ' "$output_file" || true)
infos=$(grep -Ec '^[[:space:]]*info (-|•) ' "$output_file" || true)

if [ "$errors" -gt "$baseline_errors" ] ||
  [ "$warnings" -gt "$baseline_warnings" ] ||
  [ "$infos" -gt "$baseline_infos" ]; then
  echo "::error::Analysis exceeds baseline: errors=$errors/$baseline_errors, warnings=$warnings/$baseline_warnings, infos=$infos/$baseline_infos."
  exit 1
fi

echo "Static analysis is within baseline: errors=$errors, warnings=$warnings, infos=$infos."
