#!/usr/bin/env bash
set -e

# Bring up the stack in background and return to host shell.
# This script does NOT enter container shells.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "${ROOT_DIR}"

if [ ! -f .env ]; then
  cp .env.example .env
  echo "已生成 .env，请先编辑 RAW_SUB_URL 后重试。"
  exit 1
fi

# shellcheck disable=SC1091
. "${SCRIPT_DIR}/common-env.sh"

./scripts/sync-dashboard-config.sh
docker compose up -d --build

echo "启动完成。"
echo "Web 管理地址: $(dashboard_url)"
echo "已返回宿主机终端。"
