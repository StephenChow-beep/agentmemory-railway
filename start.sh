#!/usr/bin/env bash
set -euo pipefail

export HOME=/app
export PATH="/app/.local/bin:${PATH}"

# Railway public API port.
export PORT="${PORT:-8080}"

# Optional viewer port for a protected Caddy proxy.
export VIEWER_PORT="${VIEWER_PORT:-8082}"

# Persistent Railway volume paths.
export III_DATA_DIR="${III_DATA_DIR:-/data}"
export AGENTMEMORY_DATA_DIR="${AGENTMEMORY_DATA_DIR:-/data}"

# Viewer variables, if this Agentmemory version reads them.
export AGENTMEMORY_VIEWER_HOST="${AGENTMEMORY_VIEWER_HOST:-0.0.0.0}"
export AGENTMEMORY_VIEWER_PORT="${AGENTMEMORY_VIEWER_PORT:-${VIEWER_PORT}}"
export AGENTMEMORY_VIEWER_URL="${AGENTMEMORY_VIEWER_URL:-http://0.0.0.0:${VIEWER_PORT}}"

mkdir -p /data
mkdir -p /app

echo "[railway] Starting agentmemory"
echo "[railway] PORT=${PORT}"
echo "[railway] VIEWER_PORT=${VIEWER_PORT}"
echo "[railway] III_DATA_DIR=${III_DATA_DIR}"
echo "[railway] AGENTMEMORY_DATA_DIR=${AGENTMEMORY_DATA_DIR}"
echo "[railway] AGENTMEMORY_VIEWER_HOST=${AGENTMEMORY_VIEWER_HOST}"
echo "[railway] AGENTMEMORY_VIEWER_PORT=${AGENTMEMORY_VIEWER_PORT}"
echo "[railway] AGENTMEMORY_VIEWER_URL=${AGENTMEMORY_VIEWER_URL}"

# Railway volumes are usually mounted root-owned.
# The official Agentmemory docker-compose fixes /data ownership before iii starts.
# This is safe even if the process ends up running as root.
echo "[railway] Fixing /data permissions..."
chown -R 65532:65532 /data || true
chmod 755 /data || true

# Verify that /data is writable.
echo "[railway] Testing /data write access..."
echo "ok" > /data/.railway-write-test
cat /data/.railway-write-test
rm -f /data/.railway-write-test

DIST_DIR="/usr/local/lib/node_modules/@agentmemory/agentmemory/dist"
SOURCE_CONFIG="${DIST_DIR}/iii-config.docker.yaml"
DEFAULT_CONFIG="${DIST_DIR}/iii-config.yaml"
RAILWAY_CONFIG="/app/iii-config.railway.yaml"

if [ ! -f "$SOURCE_CONFIG" ]; then
  echo "[railway] ERROR: missing ${SOURCE_CONFIG}"
  echo "[railway] dist content:"
  ls -la "$DIST_DIR" || true
  exit 1
fi

# Start from Agentmemory's official Docker config.
cp "$SOURCE_CONFIG" "$RAILWAY_CONFIG"

# Only patch the YAML config.
# Do NOT patch compiled JS files in dist.
sed -i "s/host: 127.0.0.1/host: 0.0.0.0/g" "$RAILWAY_CONFIG"
sed -i "s/host: localhost/host: 0.0.0.0/g" "$RAILWAY_CONFIG"

# Adapt the REST API port to Railway's public PORT.
sed -i "0,/port: 3111/s//port: ${PORT}/" "$RAILWAY_CONFIG"

# Adapt viewer port only in YAML if present.
sed -i "s/port: 3113/port: ${VIEWER_PORT}/g" "$RAILWAY_CONFIG"
sed -i "s/port: 8082/port: ${VIEWER_PORT}/g" "$RAILWAY_CONFIG"

# Agentmemory internally loads this default config path.
cp "$RAILWAY_CONFIG" "$DEFAULT_CONFIG"

echo "[railway] Overwrote default config:"
echo "[railway] ${DEFAULT_CONFIG}"

echo "[railway] Effective config preview:"
cat "$DEFAULT_CONFIG"

echo "[railway] Expected:"
echo "[railway] API listener should be 0.0.0.0:${PORT}"
echo "[railway] Stream listener should be 0.0.0.0:3112"
echo "[railway] Engine internal connection should remain localhost:49134"
echo "[railway] Viewer may be available on ${VIEWER_PORT}, depending on Agentmemory version"

echo "[railway] Launching agentmemory..."

exec agentmemory \
  --port "${PORT}" \
  --verbose