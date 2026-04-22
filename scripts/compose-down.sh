#!/usr/bin/env bash
set -e

# Stop and remove compose services for this project.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${ROOT_DIR}"

docker compose down
echo "容器已停止。"
