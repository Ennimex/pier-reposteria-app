#!/usr/bin/env bash
# tool/entorno_pruebas.sh — genera el entorno aislado de pruebas: la API del
# backend y su base de datos en contenedores (docker/compose.pruebas.yml), con
# datos ficticios y sin tocar producción. Lo usa el pipeline y cualquiera que
# tenga Docker:
#
#   bash tool/entorno_pruebas.sh levantar   # descarga el backend, construye y espera a que esté sano
#   bash tool/entorno_pruebas.sh estado     # contenedores y respuesta de /api/health
#   bash tool/entorno_pruebas.sh logs       # bitácoras de la API y de la base
#   bash tool/entorno_pruebas.sh bajar      # apaga y borra todo, base incluida
#
# Con el entorno arriba, la API queda en http://localhost:3000/api (desde el
# emulador de Android, http://10.0.2.2:3000/api).
#
# El backend (PedroRubioo/pier-reposteria-backend) se descarga en .backend/
# (Git lo ignora) al commit de docker/backend.version, para que todas las
# corridas prueben el mismo código. Si .backend/ ya está en ese commit (el
# pipeline lo descarga con actions/checkout), se usa tal cual.
set -euo pipefail

raiz="$(cd "$(dirname "$0")/.." && pwd)"
compose="$raiz/docker/compose.pruebas.yml"
carpeta_backend="$raiz/.backend"
repositorio_backend="https://github.com/PedroRubioo/pier-reposteria-backend.git"
commit_backend="$(tr -d '[:space:]' < "$raiz/docker/backend.version")"
url_salud="http://localhost:3000/api/health"
bitacora_si_falla="$raiz/build/resultados/entorno_logs.txt"

# Deja .backend/ en el commit fijo: lo descarga si no existe y cambia de
# commit si está en otro. Solo baja ese commit, no toda la historia.
preparar_backend() {
  if [ ! -d "$carpeta_backend/.git" ]; then
    echo "Descargando el backend en .backend/ (commit $commit_backend)..."
    git init --quiet "$carpeta_backend"
    git -C "$carpeta_backend" remote add origin "$repositorio_backend"
  fi
  # Recién creado, .backend/ todavía no tiene ningún commit.
  commit_actual="ninguno"
  if git -C "$carpeta_backend" rev-parse --verify --quiet 'HEAD^{commit}' > /dev/null; then
    commit_actual="$(git -C "$carpeta_backend" rev-parse HEAD)"
  fi
  if [ "$commit_actual" != "$commit_backend" ]; then
    git -C "$carpeta_backend" fetch --quiet --depth 1 origin "$commit_backend"
    git -C "$carpeta_backend" checkout --quiet --detach FETCH_HEAD
  fi
  echo "Backend en .backend/: commit $(git -C "$carpeta_backend" rev-parse HEAD)"
}

# Construye las imágenes, enciende los dos contenedores y espera a que los
# dos estén sanos (healthchecks de compose.pruebas.yml). Si no lo logra en
# 5 minutos, guarda las bitácoras para el artefacto del pipeline y falla.
levantar() {
  preparar_backend
  if docker compose -f "$compose" up --detach --build --wait --wait-timeout 300; then
    echo "Entorno aislado listo:"
    curl --silent --show-error "$url_salud"
    echo
  else
    codigo_de_compose=$?
    mkdir -p "$(dirname "$bitacora_si_falla")"
    docker compose -f "$compose" logs --no-color > "$bitacora_si_falla"
    echo "::error::El entorno aislado no quedó sano (docker compose terminó con $codigo_de_compose). Bitácoras en build/resultados/entorno_logs.txt."
    tail -n 60 "$bitacora_si_falla"
    exit 1
  fi
}

bajar() {
  docker compose -f "$compose" down --volumes --remove-orphans
}

estado() {
  docker compose -f "$compose" ps
  curl --silent --show-error "$url_salud"
  echo
}

logs() {
  docker compose -f "$compose" logs --no-color
}

comando="${1:-}"
case "$comando" in
  levantar) levantar ;;
  bajar) bajar ;;
  estado) estado ;;
  logs) logs ;;
  *)
    echo "Uso: bash tool/entorno_pruebas.sh levantar|bajar|estado|logs" >&2
    exit 64
    ;;
esac
