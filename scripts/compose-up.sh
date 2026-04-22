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

container_engine="$(resolve_container_engine)"
require_compose_command "${container_engine}"

if [ "${container_engine}" = "podman" ]; then
  if ! podman image exists localhost/mihomo-core:latest; then
    echo "错误：未找到镜像 localhost/mihomo-core:latest，请先执行离线镜像导入或构建并打 tag。" >&2
    exit 1
  fi
  if ! podman image exists localhost/subconverter:latest && ! podman image exists docker.io/tindy2013/subconverter:latest; then
    echo "错误：未找到 subconverter 镜像（localhost/subconverter:latest 或 docker.io/tindy2013/subconverter:latest）。" >&2
    exit 1
  fi
fi

./scripts/sync-dashboard-config.sh
${COMPOSE_CMD} -f "${COMPOSE_FILE}" up -d --build

echo "启动完成。"
echo "容器引擎: ${container_engine}"
echo "Web 管理地址: $(dashboard_url)"
echo "已返回宿主机终端。"
