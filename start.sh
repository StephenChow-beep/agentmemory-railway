#!/usr/bin/env bash
set -euo pipefail

export HOME=/app
export PATH="/app/.local/bin:${PATH}"

# Railway public API port.
export PORT="${PORT:-8080}"

# Persistent Railway volume paths.
export III_DATA_DIR="${III_DATA_DIR:-/data}"
export AGENTMEMORY_DATA_DIR="${AGENTMEMORY_DATA_DIR:-/data}"

mkdir -p /data
mkdir -p /app
mkdir -p /app/.agentmemory

echo "[railway] Starting agentmemory"
echo "[railway] PORT=${PORT}"
echo "[railway] HOME=${HOME}"
echo "[railway] III_DATA_DIR=${III_DATA_DIR}"
echo "[railway] AGENTMEMORY_DATA_DIR=${AGENTMEMORY_DATA_DIR}"

echo "[railway] Fixing /data permissions..."
chown -R 65532:65532 /data || true
chmod 755 /data || true

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

# Only expose the REST API for Railway.
# Do NOT patch viewer ports or compiled JS files.
sed -i "s/host: 127.0.0.1/host: 0.0.0.0/g" "$RAILWAY_CONFIG"
sed -i "s/host: localhost/host: 0.0.0.0/g" "$RAILWAY_CONFIG"

# Adapt the REST API port to Railway's public PORT.
sed -i "0,/port: 3111/s//port: ${PORT}/" "$RAILWAY_CONFIG"

# Agentmemory internally loads this default config path.
cp "$RAILWAY_CONFIG" "$DEFAULT_CONFIG"

echo "[railway] Overwrote default config:"
echo "[railway] ${DEFAULT_CONFIG}"

echo "[railway] Effective config preview:"
cat "$DEFAULT_CONFIG"

echo "[railway] Expected:"
echo "[railway] API listener should be 0.0.0.0:${PORT}"
echo "[railway] Stream listener should be whatever Agentmemory config defines"
echo "[railway] Viewer should use Agentmemory defaults"

echo "[railway] Writing /app/.agentmemory/.env from Railway variables..."

cat > /app/.agentmemory/.env <<EOF
AGENTMEMORY_DATA_DIR=${AGENTMEMORY_DATA_DIR}
III_DATA_DIR=${III_DATA_DIR}
AGENTMEMORY_REQUIRE_HTTPS=${AGENTMEMORY_REQUIRE_HTTPS:-1}
AGENTMEMORY_SECRET=${AGENTMEMORY_SECRET:-}
PUBLIC_AGENTMEMORY_URL=${PUBLIC_AGENTMEMORY_URL:-}
AGENTMEMORY_AUTO_COMPRESS=${AGENTMEMORY_AUTO_COMPRESS:-false}
AGENTMEMORY_INJECT_CONTEXT=${AGENTMEMORY_INJECT_CONTEXT:-false}
EMBEDDING_PROVIDER=${EMBEDDING_PROVIDER}
ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
ANTHROPIC_BASE_URL=${ANTHROPIC_BASE_URL}
AGENTMEMORY_SECRET=${AGENTMEMORY_SECRET}
GRAPH_EXTRACTION_ENABLED=${GRAPH_EXTRACTION_ENABLED}
AGENTMEMORY_LLM_TIMEOUT_MS=${AGENTMEMORY_LLM_TIMEOUT_MS}
AGENTMEMORY_AUTO_COMPRESS=${AGENTMEMORY_AUTO_COMPRESS}
CONSOLIDATION_ENABLED=${CONSOLIDATION_ENABLED}
EOF

echo "[railway] Writing /app/.agentmemory/preferences.json to skip interactive first-run..."

cat > /app/.agentmemory/preferences.json <<EOF
{
  "schemaVersion": 1,
  "lastAgent": null,
  "lastAgents": [],
  "lastProvider": null,
  "skipSplash": true,
  "skipNpxHint": true,
  "skipGlobalInstall": true,
  "skipConsoleInstall": true,
  "firstRunAt": "2026-05-15T00:00:00.000Z"
}
EOF

chmod 600 /app/.agentmemory/.env || true
chmod 600 /app/.agentmemory/preferences.json || true

echo "[railway] Agentmemory env preview:"
grep -v "SECRET" /app/.agentmemory/.env || true

echo "[railway] Agentmemory preferences preview:"
cat /app/.agentmemory/preferences.json || true

echo "[railway] Node homedir check:"
node -e 'const os=require("os"); console.log(os.homedir())'

echo "[railway] Launching agentmemory..."

export VIEWER_PUBLIC_PORT="${VIEWER_PUBLIC_PORT:-8083}"
export VIEWER_INTERNAL_PORT="${VIEWER_INTERNAL_PORT:-8082}"

echo "[railway] Starting viewer proxy:"
echo "[railway] 0.0.0.0:${VIEWER_PUBLIC_PORT} -> 127.0.0.1:${VIEWER_INTERNAL_PORT}"

socat TCP-LISTEN:${VIEWER_PUBLIC_PORT},bind=0.0.0.0,fork,reuseaddr TCP:127.0.0.1:${VIEWER_INTERNAL_PORT} &

exec agentmemory \
  --port "${PORT}" \
  --verbose
