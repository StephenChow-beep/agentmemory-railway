#!/usr/bin/env bash
set -euo pipefail

export HOME=/app
export PATH="/app/.local/bin:${PATH}"

# Railway injecte souvent PORT=8080.
# Ne force pas 3111 ici : on respecte le port Railway.
export PORT="${PORT:-8080}"

export III_DATA_DIR="${III_DATA_DIR:-/data}"
export AGENTMEMORY_DATA_DIR="${AGENTMEMORY_DATA_DIR:-/data}"

mkdir -p /data
mkdir -p /app

# Utilise la vraie config Docker fournie par agentmemory.
# Elle a le bon format "workers:" et utilise /data.
SOURCE_CONFIG="/usr/local/lib/node_modules/@agentmemory/agentmemory/dist/iii-config.docker.yaml"

if [ ! -f "$SOURCE_CONFIG" ]; then
  echo "[railway] ERROR: config Docker introuvable: $SOURCE_CONFIG"
  echo "[railway] Contenu dist:"
  ls -la /usr/local/lib/node_modules/@agentmemory/agentmemory/dist || true
  exit 1
fi

cp "$SOURCE_CONFIG" /app/iii-config.railway.yaml

# La config Docker officielle écoute sur 0.0.0.0:3111.
# Railway veut que l'app écoute sur $PORT, donc on remplace le port HTTP par $PORT.
# Le host reste 0.0.0.0.
sed -i "0,/port: 3111/s//port: ${PORT}/" /app/iii-config.railway.yaml

echo "[railway] Starting agentmemory"
echo "[railway] PORT=${PORT}"
echo "[railway] III_DATA_DIR=${III_DATA_DIR}"
echo "[railway] AGENTMEMORY_DATA_DIR=${AGENTMEMORY_DATA_DIR}"
echo "[railway] Config: /app/iii-config.railway.yaml"
echo "[railway] Config preview:"
cat /app/iii-config.railway.yaml

exec agentmemory \
  --config /app/iii-config.railway.yaml \
  --port "${PORT}" \
  --verbose