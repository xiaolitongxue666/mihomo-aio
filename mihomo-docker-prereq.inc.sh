#!/usr/bin/env bash
# shellcheck shell=bash

mihomo_docker_log() {
  printf '[mihomo-docker-prereq] %s\n' "$*" >&2
}

mihomo_docker_compose_ok() {
  command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1 && return 0
  command -v docker-compose >/dev/null 2>&1 && return 0
  return 1
}

mihomo_docker_ce_apt_urls_for_os() {
  local os_key="$1"
  local mode="${DOCKER_CE_APT_MIRROR:-auto}"
  local official_gpg="https://download.docker.com/linux/${os_key}/gpg"
  local official_root="https://download.docker.com/linux/${os_key}"
  case "$mode" in
    official) printf '%s\t%s\n' "$official_gpg" "$official_root" ;;
    ustc) printf '%s\t%s\n' "https://mirrors.ustc.edu.cn/docker-ce/linux/${os_key}/gpg" "https://mirrors.ustc.edu.cn/docker-ce/linux/${os_key}" ;;
    aliyun) printf '%s\t%s\n' "https://mirrors.aliyun.com/docker-ce/linux/${os_key}/gpg" "https://mirrors.aliyun.com/docker-ce/linux/${os_key}" ;;
    auto)
      if curl -fsSL --connect-timeout 6 --max-time 20 "$official_gpg" -o /dev/null 2>/dev/null; then
        printf '%s\t%s\n' "$official_gpg" "$official_root"
      else
        printf '%s\t%s\n' "https://mirrors.ustc.edu.cn/docker-ce/linux/${os_key}/gpg" "https://mirrors.ustc.edu.cn/docker-ce/linux/${os_key}"
      fi
      ;;
    *) return 1 ;;
  esac
}

mihomo_install_docker_write_apt_sources() {
  local os_key="$1" arch="$2" codename="$3"
  local mode gpg_url deb_root tmp_file
  for mode in auto ustc aliyun official; do
    [ "${DOCKER_CE_APT_MIRROR:-auto}" = "auto" ] || mode="${DOCKER_CE_APT_MIRROR}"
    IFS=$'\t' read -r gpg_url deb_root < <(DOCKER_CE_APT_MIRROR="$mode" mihomo_docker_ce_apt_urls_for_os "$os_key") || true
    [ -n "${gpg_url:-}" ] || continue
    tmp_file="/etc/apt/keyrings/docker.gpg.tmp.$$"
    rm -f "$tmp_file"
    if curl -fsSL --connect-timeout 15 --max-time 120 "$gpg_url" | gpg --batch --no-tty --dearmor -o "$tmp_file" 2>/dev/null && [ -s "$tmp_file" ]; then
      mv "$tmp_file" /etc/apt/keyrings/docker.gpg
      chmod a+r /etc/apt/keyrings/docker.gpg
      echo "deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.gpg] ${deb_root} ${codename} stable" >/etc/apt/sources.list.d/docker.list
      return 0
    fi
    rm -f "$tmp_file"
    [ "${DOCKER_CE_APT_MIRROR:-auto}" = "auto" ] || break
  done
  return 1
}

mihomo_install_docker_linux() {
  mihomo_docker_compose_ok && return 0

  [ -f /etc/os-release ] || { mihomo_docker_log "缺少 /etc/os-release"; return 1; }
  local os_id codename arch
  os_id="$(sed -n 's/^ID=//p' /etc/os-release | tr -d '"' | tr '[:upper:]' '[:lower:]' | sed -n '1p')"
  codename="$(sed -n 's/^VERSION_CODENAME=//p' /etc/os-release | tr -d '"' | sed -n '1p')"
  [ -n "$codename" ] || codename="$(lsb_release -cs 2>/dev/null || true)"
  case "$os_id" in ubuntu|debian) ;; *) mihomo_docker_log "仅支持 ubuntu/debian 自动安装"; return 1;; esac

  DEBIAN_FRONTEND=noninteractive apt-get update -y -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq ca-certificates curl gnupg lsb-release jq

  install -m 0755 -d /etc/apt/keyrings
  rm -f /etc/apt/keyrings/docker.gpg
  arch="$(dpkg --print-architecture)"
  mihomo_install_docker_write_apt_sources "$os_id" "$arch" "$codename" || return 1

  DEBIAN_FRONTEND=noninteractive apt-get update -y -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  if command -v systemctl >/dev/null 2>&1; then
    systemctl enable docker 2>/dev/null || true
    systemctl start docker 2>/dev/null || true
  fi

  mihomo_docker_compose_ok
}

mihomo_ensure_docker_engine() {
  [ "${MIHOMO_SKIP_DOCKER_ENSURE:-0}" = "1" ] && return 0
  if mihomo_docker_compose_ok; then
    if command -v systemctl >/dev/null 2>&1; then
      systemctl start docker 2>/dev/null || true
    fi
    return 0
  fi

  case "$(uname -s 2>/dev/null || true)" in
    Linux) ;;
    Darwin) mihomo_docker_log "请安装并启动 Docker Desktop"; return 1 ;;
    *) mihomo_docker_log "当前平台不支持自动安装 Docker"; return 1 ;;
  esac

  if [ "${EUID:-0}" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
      sudo env MIHOMO_DOCKER_PREREQ_INC="${BASH_SOURCE[0]}" DOCKER_CE_APT_MIRROR="${DOCKER_CE_APT_MIRROR:-auto}" \
        bash -c 'set -euo pipefail; . "$MIHOMO_DOCKER_PREREQ_INC"; mihomo_install_docker_linux'
      return $?
    fi
    mihomo_docker_log "需要 root 或免密 sudo"
    return 1
  fi

  mihomo_install_docker_linux
}
