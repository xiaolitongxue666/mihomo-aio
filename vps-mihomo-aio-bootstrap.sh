#!/usr/bin/env bash
set -euo pipefail

if [ "${EUID:-0}" -ne 0 ]; then
  echo "错误：请使用 root 执行，例如: sudo bash $0" >&2
  exit 1
fi

BOOTSTRAP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAGING_DIR="$(cd "${1:-.}" && pwd)"
ZIP="${STAGING_DIR}/mihomo-aio-bundle.zip"
IMG_TGZ="${STAGING_DIR}/mihomo-aio-images.tar.gz"

for needed_command in unzip tar gunzip; do
  command -v "$needed_command" >/dev/null 2>&1 || { echo "错误：缺少命令 $needed_command" >&2; exit 1; }
done

[ -f "$ZIP" ] || { echo "错误：未找到 ${ZIP}" >&2; exit 1; }
[ -f "$IMG_TGZ" ] || { echo "错误：未找到 ${IMG_TGZ}" >&2; exit 1; }

get_env_value() {
  local file="$1" key="$2"
  sed -n "s/^${key}=//p" "$file" | sed -n '1p' | sed 's/\r$//' | sed 's/^["'\'' ]*//;s/["'\'' ]*$//'
}

preview_env_file="$(mktemp)"
image_temp_dir=""
cleanup() {
  rm -f "$preview_env_file"
  [ -n "$image_temp_dir" ] && [ -d "$image_temp_dir" ] && rm -rf "$image_temp_dir"
}
trap cleanup EXIT
unzip -p "$ZIP" ".env" >"$preview_env_file" 2>/dev/null || { echo "错误：zip 中缺少 .env" >&2; exit 1; }

DEPLOY_DIR="$(get_env_value "$preview_env_file" VPS_DEPLOY_DEPLOY_DIR)"
ENGINE="$(get_env_value "$preview_env_file" VPS_DEPLOY_CONTAINER_ENGINE)"
DEPLOY_DIR="${DEPLOY_DIR:-/opt/mihomo-aio}"
ENGINE="$(printf '%s' "${ENGINE:-docker}" | tr '[:upper:]' '[:lower:]')"
case "$ENGINE" in docker|podman) ;; *) echo "错误：VPS_DEPLOY_CONTAINER_ENGINE 必须是 docker/podman" >&2; exit 1;; esac

if [ "${MIHOMO_SKIP_DOCKER_ENSURE:-0}" != "1" ]; then
  [ -f "${BOOTSTRAP_DIR}/mihomo-docker-prereq.inc.sh" ] || { echo "错误：缺少 mihomo-docker-prereq.inc.sh" >&2; exit 1; }
  # shellcheck disable=SC1091
  . "${BOOTSTRAP_DIR}/mihomo-docker-prereq.inc.sh"
  mihomo_ensure_docker_engine || exit 1
fi

if [ "${MIHOMO_SKIP_PODMAN_ENSURE:-0}" != "1" ]; then
  [ -f "${BOOTSTRAP_DIR}/mihomo-podman-prereq.inc.sh" ] || { echo "错误：缺少 mihomo-podman-prereq.inc.sh" >&2; exit 1; }
  # shellcheck disable=SC1091
  . "${BOOTSTRAP_DIR}/mihomo-podman-prereq.inc.sh"
  mihomo_ensure_podman_engine || exit 1
fi

command -v "$ENGINE" >/dev/null 2>&1 || { echo "错误：未找到容器命令: $ENGINE" >&2; exit 1; }

echo "=== mihomo-aio VPS 离线部署 ==="
echo "STAGING_DIR=${STAGING_DIR}"
echo "DEPLOY_DIR=${DEPLOY_DIR}"
echo "ENGINE=${ENGINE}"

image_temp_dir="$(mktemp -d)"
tar xzf "$IMG_TGZ" -C "$image_temp_dir"
(
  cd "$image_temp_dir"
  [ -f mihomo-core.tar.gz ] && gunzip -f mihomo-core.tar.gz
  [ -f subconverter.tar.gz ] && gunzip -f subconverter.tar.gz
  [ -f nginx-alpine.tar.gz ] && gunzip -f nginx-alpine.tar.gz
  [ -f mihomo-core.tar ] || { echo "错误：镜像包缺少 mihomo-core.tar(.gz)" >&2; exit 1; }
  [ -f subconverter.tar ] || { echo "错误：镜像包缺少 subconverter.tar(.gz)" >&2; exit 1; }
  [ -f nginx-alpine.tar ] || { echo "错误：镜像包缺少 nginx-alpine.tar(.gz)；请用新版 deploy-remote.sh pack 重新打包" >&2; exit 1; }
  "$ENGINE" load -i mihomo-core.tar
  "$ENGINE" load -i subconverter.tar
  "$ENGINE" load -i nginx-alpine.tar
)

mkdir -p "$DEPLOY_DIR"
unzip -o -q "$ZIP" -d "$DEPLOY_DIR"

if [ "$ENGINE" = "podman" ]; then
  loaded_core_image="$($ENGINE images --format "{{.Repository}}:{{.Tag}}" | sed -n '/mihomo.*core/p' | sed -n '1p' || true)"
  loaded_subconverter_image="$($ENGINE images --format "{{.Repository}}:{{.Tag}}" | sed -n '/subconverter/p' | sed -n '1p' || true)"
  [ -n "$loaded_core_image" ] || { echo "错误：未找到已加载的 mihomo-core 镜像" >&2; exit 1; }
  [ -n "$loaded_subconverter_image" ] || { echo "错误：未找到已加载的 subconverter 镜像" >&2; exit 1; }
  "$ENGINE" tag "$loaded_core_image" "localhost/mihomo-core:latest"
  "$ENGINE" tag "$loaded_subconverter_image" "localhost/subconverter:latest"
  loaded_dashboard_image="$($ENGINE images --format "{{.Repository}}:{{.Tag}}" | sed -n '/nginx/p' | sed -n '1p' || true)"
  [ -n "$loaded_dashboard_image" ] || { echo "错误：未找到已加载的 dashboard/nginx 镜像" >&2; exit 1; }
  "$ENGINE" tag "$loaded_dashboard_image" "localhost/mihomo-aio-dashboard:latest"
elif [ "$ENGINE" = "docker" ]; then
  loaded_core_image="$($ENGINE images --format "{{.Repository}}:{{.Tag}}" | sed -n '/mihomo[-_]aio[-_]mihomo[-_]core/p' | sed -n '1p' || true)"
  [ -z "$loaded_core_image" ] && loaded_core_image="$($ENGINE images --format "{{.Repository}}:{{.Tag}}" | sed -n '/mihomo.*core/p' | sed -n '1p' || true)"
  if [ -n "$loaded_core_image" ] && [ "$loaded_core_image" != "mihomo-aio-mihomo-core:latest" ]; then
    "$ENGINE" tag "$loaded_core_image" "mihomo-aio-mihomo-core:latest"
  fi
fi

cd "$DEPLOY_DIR"
if [ -f "${DEPLOY_DIR}/.env" ]; then
  echo "=== 本栈将发布的主机端口（${DEPLOY_DIR}/.env）==="
  grep -E '^(ALL_PROXY_PORT|EXTERNAL_CONTROLLER_PORT|CONTROL_PANEL_PORT|SUBCONVERTER_HOST_PORT)=' "${DEPLOY_DIR}/.env" 2>/dev/null || true
  echo "若端口已被占用，请编辑上述 .env 后仅在本目录执行 compose down/up，勿影响其它服务。"
fi
if [ "$ENGINE" = "podman" ]; then
  if command -v podman >/dev/null 2>&1 && podman compose version >/dev/null 2>&1; then
    podman compose -f podman-compose.yaml down 2>/dev/null || true
    podman compose -f podman-compose.yaml up -d
  elif command -v podman-compose >/dev/null 2>&1; then
    podman-compose -f podman-compose.yaml down 2>/dev/null || true
    podman-compose -f podman-compose.yaml up -d
  else
    echo "错误：未找到 podman compose 或 podman-compose" >&2
    exit 1
  fi
else
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    docker compose -f docker-compose.yaml down 2>/dev/null || true
    docker compose -f docker-compose.yaml up -d --no-build
  elif command -v docker-compose >/dev/null 2>&1; then
    docker-compose -f docker-compose.yaml down 2>/dev/null || true
    docker-compose -f docker-compose.yaml up -d --no-build
  else
    echo "错误：未找到 docker compose 或 docker-compose" >&2
    exit 1
  fi
fi

if [ -x "${DEPLOY_DIR}/scripts/health-check.sh" ]; then
  bash "${DEPLOY_DIR}/scripts/health-check.sh" || true
fi

echo "部署完成。"
