#!/usr/bin/env bash
set -e

# Enter mihomo core container for manual debugging.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${ROOT_DIR}"

CONTAINER_NAME="mihomo-aio-core"

if ! docker ps --format '{{.Names}}' | rg -n "^${CONTAINER_NAME}$" >/dev/null; then
  echo "容器 ${CONTAINER_NAME} 未运行，请先执行 ./scripts/up.sh"
  exit 1
fi

docker exec -it "${CONTAINER_NAME}" sh || docker exec -it "${CONTAINER_NAME}" bash
