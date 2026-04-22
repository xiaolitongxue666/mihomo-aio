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
: "${VPS_DEPLOY_CONTAINER_ENGINE:=docker}"

resolve_container_engine() {
  local normalized_engine
  normalized_engine="$(printf '%s' "${VPS_DEPLOY_CONTAINER_ENGINE:-docker}" | tr '[:upper:]' '[:lower:]')"
  case "${normalized_engine}" in
    docker|podman)
      echo "${normalized_engine}"
      ;;
    *)
      echo "错误：VPS_DEPLOY_CONTAINER_ENGINE 必须是 docker 或 podman，当前: ${VPS_DEPLOY_CONTAINER_ENGINE}" >&2
      return 1
      ;;
  esac
}

require_compose_command() {
  local container_engine="$1"
  case "${container_engine}" in
    docker)
      if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
        COMPOSE_CMD="docker compose"
      elif command -v docker-compose >/dev/null 2>&1; then
        COMPOSE_CMD="docker-compose"
      else
        echo "错误：未找到 docker compose 或 docker-compose。" >&2
        return 1
      fi
      COMPOSE_FILE="docker-compose.yaml"
      ;;
    podman)
      if command -v podman >/dev/null 2>&1 && command -v podman-compose >/dev/null 2>&1; then
        COMPOSE_CMD="podman-compose"
      else
        echo "错误：已选择 podman，但未找到 podman 或 podman-compose。" >&2
        return 1
      fi
      COMPOSE_FILE="podman-compose.yaml"
      ;;
    *)
      echo "错误：不支持的容器引擎: ${container_engine}" >&2
      return 1
      ;;
  esac

  if [ ! -f "${ROOT_DIR}/${COMPOSE_FILE}" ]; then
    echo "错误：未找到 compose 文件 ${COMPOSE_FILE}" >&2
    return 1
  fi
}

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
