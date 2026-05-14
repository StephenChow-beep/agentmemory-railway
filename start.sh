#!/usr/bin/env bash
set -euo pipefail

export HOME=/app
export PATH="/app/.local/bin:$PATH"

# Forcer les données persistantes dans le volume Railway
export III_DATA_DIR="${III_DATA_DIR:-/data}"
export AGENTMEMORY_DATA_DIR="${AGENTMEMORY_DATA_DIR:-/data}"
export AGENTMEMORY_URL="${AGENTMEMORY_URL:-http://127.0.0.1:3111}"
export AGENTMEMORY_VIEWER_URL="${AGENTMEMORY_VIEWER_URL:-http://127.0.0.1:3113}"

# Railway fournit PORT, mais agentmemory utilise 3111 par défaut.
# On le force explicitement pour éviter les surprises.
exec agentmemory --port 3111 --verbose