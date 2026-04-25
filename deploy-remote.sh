#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

BUNDLE_ZIP_NAME="mihomo-aio-bundle.zip"
IMAGES_TGZ_NAME="mihomo-aio-images.tar.gz"
DIST_DIR="${SCRIPT_DIR}/dist"

usage() {
  echo "用法: $0 pack | upload | all" >&2
  exit 1
}

deploy_get_env() {
  local key="$1"
  local file="${2:-${SCRIPT_DIR}/.env}"
  [ -f "$file" ] || return 1
  sed -n "s/^${key}=//p" "$file" | sed -n '1p' | sed 's/\r$//' | sed 's/^["'\'' ]*//;s/["'\'' ]*$//'
}

require_cmds() {
  local missing=""
  for command_name in "$@"; do
    command -v "$command_name" >/dev/null 2>&1 || missing="${missing} ${command_name}"
  done
  [ -z "$missing" ] || { echo "错误：缺少命令:${missing}" >&2; exit 1; }
}

detect_compose_cmd() {
  if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    echo "docker compose"
  elif command -v docker-compose >/dev/null 2>&1; then
    echo "docker-compose"
  else
    echo "错误：未找到 docker compose 或 docker-compose。" >&2
    exit 1
  fi
}

cmd_pack() {
  require_cmds docker tar gzip zip
  local compose_cmd
  compose_cmd="$(detect_compose_cmd)"
  [ -f "${SCRIPT_DIR}/.env" ] || { echo "错误：缺少 .env" >&2; exit 1; }

  mkdir -p "$DIST_DIR"
  local image_work_dir compose_images_file
  image_work_dir="$(mktemp -d)"
  compose_images_file="$(mktemp)"
  cleanup_pack() {
    rm -rf "$image_work_dir"
    rm -f "$compose_images_file"
  }
  trap cleanup_pack RETURN

  if [ "$compose_cmd" = "docker compose" ]; then
    docker compose -f docker-compose.yaml build
    docker compose -f docker-compose.yaml config --images >"$compose_images_file"
  else
    docker-compose -f docker-compose.yaml build
    docker-compose -f docker-compose.yaml config --images >"$compose_images_file"
  fi

  local core_image="" subconverter_image="" dashboard_image="" line
  while IFS= read -r line || [ -n "$line" ]; do
    [ -z "$line" ] && continue
    case "$line" in
      *subconverter*) subconverter_image="$line" ;;
      *mihomo*core* | *mihomo-aio*) core_image="$line" ;;
      *nginx*) dashboard_image="$line" ;;
    esac
  done <"$compose_images_file"

  [ -n "$core_image" ] || { echo "错误：无法解析 mihomo core 镜像名。" >&2; exit 1; }
  [ -n "$subconverter_image" ] || { echo "错误：无法解析 subconverter 镜像名。" >&2; exit 1; }
  [ -n "$dashboard_image" ] || { echo "错误：无法解析 dashboard/nginx 镜像名。" >&2; exit 1; }
  case "$core_image" in *:*) ;; *) core_image="${core_image}:latest" ;; esac
  case "$subconverter_image" in *:*) ;; *) subconverter_image="${subconverter_image}:latest" ;; esac
  case "$dashboard_image" in *:*) ;; *) dashboard_image="${dashboard_image}:latest" ;; esac

  docker image inspect "$dashboard_image" >/dev/null 2>&1 || docker pull "$dashboard_image"

  docker save "$core_image" -o "${image_work_dir}/mihomo-core.tar"
  docker save "$subconverter_image" -o "${image_work_dir}/subconverter.tar"
  docker save "$dashboard_image" -o "${image_work_dir}/nginx-alpine.tar"
  gzip -f "${image_work_dir}/mihomo-core.tar" "${image_work_dir}/subconverter.tar" "${image_work_dir}/nginx-alpine.tar"
  tar czf "${DIST_DIR}/${IMAGES_TGZ_NAME}" -C "$image_work_dir" mihomo-core.tar.gz subconverter.tar.gz nginx-alpine.tar.gz

  rm -f "${DIST_DIR}/${BUNDLE_ZIP_NAME}"
  zip -q -r "${DIST_DIR}/${BUNDLE_ZIP_NAME}" \
    docker-compose.yaml podman-compose.yaml Dockerfile entrypoint.sh scripts dashboard data .env .env.example \
    mihomo-docker-prereq.inc.sh mihomo-podman-prereq.inc.sh vps-mihomo-aio-bootstrap.sh README.md DEPLOYMENT.md

  trap - RETURN
  cleanup_pack

  echo "完成: ${DIST_DIR}/${BUNDLE_ZIP_NAME}"
  echo "      ${DIST_DIR}/${IMAGES_TGZ_NAME}"
}

cmd_upload() {
  require_cmds scp ssh
  local env_file host port user private_key remote_dir engine
  env_file="${SCRIPT_DIR}/.env"
  [ -f "$env_file" ] || { echo "错误：缺少 ${env_file}" >&2; exit 1; }

  host="$(deploy_get_env VPS_DEPLOY_SSH_HOST "$env_file")"
  port="$(deploy_get_env VPS_DEPLOY_SSH_PORT "$env_file")"
  user="$(deploy_get_env VPS_DEPLOY_SSH_USER "$env_file")"
  private_key="$(deploy_get_env VPS_DEPLOY_SSH_KEY "$env_file")"
  remote_dir="$(deploy_get_env VPS_DEPLOY_REMOTE_DIR "$env_file")"
  engine="$(deploy_get_env VPS_DEPLOY_CONTAINER_ENGINE "$env_file")"

  port="${port:-22}"
  engine="$(printf '%s' "${engine:-docker}" | tr '[:upper:]' '[:lower:]')"
  [ -n "$host" ] && [ -n "$user" ] && [ -n "$remote_dir" ] || {
    echo "错误：请在 .env 配置 VPS_DEPLOY_SSH_HOST/VPS_DEPLOY_SSH_USER/VPS_DEPLOY_REMOTE_DIR" >&2; exit 1; }
  case "$engine" in docker|podman) ;; *) echo "错误：VPS_DEPLOY_CONTAINER_ENGINE 必须是 docker/podman" >&2; exit 1;; esac

  [ -s "${DIST_DIR}/${BUNDLE_ZIP_NAME}" ] && [ -s "${DIST_DIR}/${IMAGES_TGZ_NAME}" ] || {
    echo "错误：请先执行 pack" >&2; exit 1; }

  local ssh_options scp_options
  ssh_options=(-p "$port")
  scp_options=(-P "$port")
  if [ -n "$private_key" ]; then
    [ -f "$private_key" ] || { echo "错误：私钥不存在 ${private_key}" >&2; exit 1; }
    ssh_options+=(-i "$private_key" -o "IdentitiesOnly=yes")
    scp_options+=(-i "$private_key" -o "IdentitiesOnly=yes")
  fi

  host_lc="$(printf "%s" "$host" | tr "[:upper:]" "[:lower:]")"
  if [ "$host_lc" = "127.0.0.1" ] || [ "$host_lc" = "localhost" ]; then
    ssh_options+=(-o "StrictHostKeyChecking=accept-new" -o "UserKnownHostsFile=/dev/null")
    scp_options+=(-o "StrictHostKeyChecking=accept-new" -o "UserKnownHostsFile=/dev/null")
  fi

  ssh "${ssh_options[@]}" "${user}@${host}" "umask 022; mkdir -p -- $(printf "%q" "$remote_dir")"

  scp "${scp_options[@]}" \
    "${DIST_DIR}/${BUNDLE_ZIP_NAME}" \
    "${DIST_DIR}/${IMAGES_TGZ_NAME}" \
    "${SCRIPT_DIR}/vps-mihomo-aio-bootstrap.sh" \
    "${SCRIPT_DIR}/mihomo-docker-prereq.inc.sh" \
    "${SCRIPT_DIR}/mihomo-podman-prereq.inc.sh" \
    "${user}@${host}:${remote_dir}"

  ssh "${ssh_options[@]}" "${user}@${host}" "
    set -euo pipefail
    cd ${remote_dir}
    test -s ${BUNDLE_ZIP_NAME}
    test -s ${IMAGES_TGZ_NAME}
    test -s vps-mihomo-aio-bootstrap.sh
    test -s mihomo-docker-prereq.inc.sh
    test -s mihomo-podman-prereq.inc.sh
    sed -i 's/\\r\\$//' vps-mihomo-aio-bootstrap.sh mihomo-docker-prereq.inc.sh mihomo-podman-prereq.inc.sh
  "

  echo "上传完成。请在远端执行: sudo bash vps-mihomo-aio-bootstrap.sh ."
}

main() {
  case "${1:-}" in
    pack) cmd_pack ;;
    upload) cmd_upload ;;
    all) cmd_pack; cmd_upload ;;
    *) usage ;;
  esac
}

main "${1:-}"
