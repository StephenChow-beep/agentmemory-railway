#!/usr/bin/env bash
set -euo pipefail

export HOME=/app
export PATH="/app/.local/bin:${PATH}"

# Railway injecte PORT=8080 dans ton cas.
# C'est le port public de l'API REST agentmemory.
export PORT="${PORT:-8080}"

# Port interne du viewer, utilisé par ton service Caddy.
export VIEWER_PORT="${VIEWER_PORT:-8082}"

# Données persistantes Railway
export III_DATA_DIR="${III_DATA_DIR:-/data}"
export AGENTMEMORY_DATA_DIR="${AGENTMEMORY_DATA_DIR:-/data}"

# Variables viewer, au cas où agentmemory les lit.
export AGENTMEMORY_VIEWER_HOST="${AGENTMEMORY_VIEWER_HOST:-0.0.0.0}"
export AGENTMEMORY_VIEWER_PORT="${AGENTMEMORY_VIEWER_PORT:-${VIEWER_PORT}}"
export AGENTMEMORY_VIEWER_URL="${AGENTMEMORY_VIEWER_URL:-http://0.0.0.0:${VIEWER_PORT}}"

mkdir -p /data
mkdir -p /app

DIST_DIR="/usr/local/lib/node_modules/@agentmemory/agentmemory/dist"
SOURCE_CONFIG="${DIST_DIR}/iii-config.docker.yaml"
DEFAULT_CONFIG="${DIST_DIR}/iii-config.yaml"
RAILWAY_CONFIG="/app/iii-config.railway.yaml"

echo "[railway] Starting agentmemory"
echo "[railway] PORT=${PORT}"
echo "[railway] VIEWER_PORT=${VIEWER_PORT}"
echo "[railway] III_DATA_DIR=${III_DATA_DIR}"
echo "[railway] AGENTMEMORY_DATA_DIR=${AGENTMEMORY_DATA_DIR}"
echo "[railway] AGENTMEMORY_VIEWER_HOST=${AGENTMEMORY_VIEWER_HOST}"
echo "[railway] AGENTMEMORY_VIEWER_PORT=${AGENTMEMORY_VIEWER_PORT}"
echo "[railway] AGENTMEMORY_VIEWER_URL=${AGENTMEMORY_VIEWER_URL}"

if [ ! -f "$SOURCE_CONFIG" ]; then
  echo "[railway] ERROR: missing ${SOURCE_CONFIG}"
  echo "[railway] dist content:"
  ls -la "$DIST_DIR" || true
  exit 1
fi

# 1. Repartir de la config Docker officielle agentmemory.
cp "$SOURCE_CONFIG" "$RAILWAY_CONFIG"

# 2. Forcer tous les hosts sur 0.0.0.0.
# Important pour Railway public networking et private networking.
sed -i "s/host: 127.0.0.1/host: 0.0.0.0/g" "$RAILWAY_CONFIG"
sed -i "s/host: localhost/host: 0.0.0.0/g" "$RAILWAY_CONFIG"

# 3. Adapter le port HTTP agentmemory au PORT Railway.
# La config Docker source est normalement sur 3111.
sed -i "0,/port: 3111/s//port: ${PORT}/" "$RAILWAY_CONFIG"

# 4. Adapter le port stream si nécessaire.
# On le garde interne, non exposé publiquement.
# S'il existe déjà en 3112, on ne touche pas.
# Le service Caddy ne doit PAS pointer ici.

# 5. Tenter de forcer le viewer sur VIEWER_PORT.
# Selon la version agentmemory, le viewer peut être défini dans la config
# ou calculé par le code. Ces remplacements couvrent les cas fréquents.
sed -i "s/port: 3113/port: ${VIEWER_PORT}/g" "$RAILWAY_CONFIG"
sed -i "s/port: 8082/port: ${VIEWER_PORT}/g" "$RAILWAY_CONFIG"

# 6. Point critique :
# Dans tes logs, agentmemory charge toujours DEFAULT_CONFIG.
# Donc on écrase directement le fichier qu'il utilise vraiment.
cp "$RAILWAY_CONFIG" "$DEFAULT_CONFIG"

# 7. Patch défensif dans le JS buildé :
# si le viewer est hardcodé sur localhost, on remplace localhost/127.0.0.1 par 0.0.0.0.
# On limite aux fichiers dist pour éviter de toucher node_modules au-delà d'agentmemory.
echo "[railway] Patching built files for viewer host if needed..."
grep -RIl "localhost\|127.0.0.1" "$DIST_DIR" 2>/dev/null | while read -r file; do
  sed -i "s/127\.0\.0\.1/0.0.0.0/g" "$file" || true
  sed -i "s/localhost/0.0.0.0/g" "$file" || true
done

# 8. Patch défensif pour le port viewer :
# si 3113 est encore hardcodé dans le build, on le remplace par VIEWER_PORT.
# Attention : on ne remplace pas 3111 ici, car l'API est déjà gérée par la config.
grep -RIl "3113" "$DIST_DIR" 2>/dev/null | while read -r file; do
  sed -i "s/3113/${VIEWER_PORT}/g" "$file" || true
done

echo "[railway] Overwrote default config:"
echo "[railway] ${DEFAULT_CONFIG}"

echo "[railway] Effective config preview:"
cat "$DEFAULT_CONFIG"

echo "[railway] Checking expected binds:"
echo "[railway] API should listen on 0.0.0.0:${PORT}"
echo "[railway] Viewer should listen on 0.0.0.0:${VIEWER_PORT}"

echo "[railway] Launching agentmemory..."

exec agentmemory \
  --port "${PORT}" \
  --verbose