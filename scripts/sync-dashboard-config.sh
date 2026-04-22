#!/usr/bin/env bash
set -e

# Generate dashboard/runtime-config.json from .env values.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"
OUT_FILE="${ROOT_DIR}/dashboard/runtime-config.json"

[ -f "${ENV_FILE}" ] || cp "${ROOT_DIR}/.env.example" "${ENV_FILE}"

read_env() {
  local key="$1"
  local val
  val=$(grep -E "^${key}=" "${ENV_FILE}" | tail -1 | cut -d= -f2- || true)
  val="${val%\"}"
  val="${val#\"}"
  echo "$val"
}

escape_json() {
  python3 - <<'PY' "$1"
import json,sys
print(json.dumps(sys.argv[1]))
PY
}

RAW_SUB_URL=$(read_env RAW_SUB_URL)
ALL_PROXY_PORT=$(read_env ALL_PROXY_PORT)
CONTROL_PANEL_PORT=$(read_env CONTROL_PANEL_PORT)
EXTERNAL_CONTROLLER_PORT=$(read_env EXTERNAL_CONTROLLER_PORT)
SUBCONVERTER_HOST_PORT=$(read_env SUBCONVERTER_HOST_PORT)
MIXED_PORT=$(read_env MIXED_PORT)
DASHBOARD_PORT=$(read_env DASHBOARD_PORT)
SUBCONVERTER_TARGET=$(read_env SUBCONVERTER_TARGET)
SUBCONVERTER_TEMPLATE=$(read_env SUBCONVERTER_TEMPLATE)
SECRET=$(read_env SECRET)

PROFILE_NAME=$(python3 - <<'PY' "$RAW_SUB_URL"
import sys, urllib.parse
u=sys.argv[1].strip()
if not u:
    print("default.yaml")
else:
    p=urllib.parse.urlparse(u)
    host=p.hostname or "subscription"
    print(f"{host}.yaml")
PY
)

mkdir -p "${ROOT_DIR}/dashboard"
cat > "${OUT_FILE}" <<JSON
{
  "source": "env",
  "updatedAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "ports": {
    "allProxyPort": ${ALL_PROXY_PORT:-17890},
    "mixedPort": ${MIXED_PORT:-7890},
    "controlPanelPort": ${CONTROL_PANEL_PORT:-19091},
    "dashboardPort": ${DASHBOARD_PORT:-80},
    "externalControllerPort": ${EXTERNAL_CONTROLLER_PORT:-19090},
    "externalControllerContainerPort": ${EXTERNAL_CONTROLLER_PORT:-19090},
    "subconverterHostPort": ${SUBCONVERTER_HOST_PORT:-25501},
    "subconverterContainerPort": 25500
  },
  "defaults": {
    "subTarget": $(escape_json "${SUBCONVERTER_TARGET:-clash}"),
    "subTemplate": $(escape_json "${SUBCONVERTER_TEMPLATE}"),
    "secret": $(escape_json "${SECRET:-change-me}")
  },
  "profiles": [
    {
      "id": "env-default",
      "name": $(escape_json "${PROFILE_NAME}"),
      "url": $(escape_json "${RAW_SUB_URL}"),
      "target": $(escape_json "${SUBCONVERTER_TARGET:-clash}"),
      "template": $(escape_json "${SUBCONVERTER_TEMPLATE}"),
      "source": "env"
    }
  ]
}
JSON

echo "synced dashboard runtime config: ${OUT_FILE}"
