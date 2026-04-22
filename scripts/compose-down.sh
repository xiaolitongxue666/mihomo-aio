#!/usr/bin/env bash
set -e

# Stop and remove compose services for this project.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${ROOT_DIR}"

# shellcheck disable=SC1091
. "${SCRIPT_DIR}/common-env.sh"

container_engine="$(resolve_container_engine)"
require_compose_command "${container_engine}"

${COMPOSE_CMD} -f "${COMPOSE_FILE}" down
echo "容器已停止（${container_engine}）。"
