#!/usr/bin/env bash
set -e

# Common environment loader for host-side scripts.
# Loads defaults from .env.example first, then overrides with .env.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

load_env_file() {
  local file="$1"
  [ -f "$file" ] || return 0
  while IFS= read -r line; do
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ "$line" =~ ^[[:space:]]*$ ]] && continue
    key="${line%%=*}"
    value="${line#*=}"
    key="$(echo "$key" | xargs)"
    value="${value%\"}"
    value="${value#\"}"
    [ -n "$key" ] && export "$key=$value"
  done < "$file"
}

load_env_file "${ROOT_DIR}/.env.example"
load_env_file "${ROOT_DIR}/.env"

: "${RAW_SUB_URL:=}"
: "${ALL_PROXY_PORT:=17890}"
: "${CONTROL_PANEL_PORT:=19091}"
: "${EXTERNAL_CONTROLLER_PORT:=19090}"
: "${MIXED_PORT:=7890}"
: "${SUBCONVERTER_HOST_PORT:=25501}"
: "${SECRET:=change-me}"

api_base_url() {
  echo "http://127.0.0.1:${EXTERNAL_CONTROLLER_PORT}"
}

dashboard_url() {
  echo "http://127.0.0.1:${CONTROL_PANEL_PORT}"
}

auth_header() {
  if [ -n "${SECRET}" ]; then
    echo "Authorization: Bearer ${SECRET}"
  fi
}
