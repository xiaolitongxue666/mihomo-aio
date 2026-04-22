#!/usr/bin/env bash
# shellcheck shell=bash

mihomo_podman_log() {
  printf '[mihomo-podman-prereq] %s\n' "$*" >&2
}

mihomo_podman_compose_ok() {
  command -v podman >/dev/null 2>&1 || return 1
  podman compose version >/dev/null 2>&1 && return 0
  command -v podman-compose >/dev/null 2>&1 && return 0
  return 1
}

mihomo_install_podman_linux() {
  mihomo_podman_compose_ok && return 0

  [ -f /etc/os-release ] || { mihomo_podman_log "缺少 /etc/os-release"; return 1; }
  local os_id
  os_id="$(sed -n 's/^ID=//p' /etc/os-release | tr -d '"' | tr '[:upper:]' '[:lower:]' | sed -n '1p')"

  case "$os_id" in
    ubuntu|debian)
      DEBIAN_FRONTEND=noninteractive apt-get update -y -qq
      DEBIAN_FRONTEND=noninteractive apt-get install -y -qq podman || return 1
      if ! DEBIAN_FRONTEND=noninteractive apt-get install -y -qq podman-compose; then
        mihomo_podman_log "apt 未提供 podman-compose，回退使用 pip3 安装"
        DEBIAN_FRONTEND=noninteractive apt-get install -y -qq python3-pip || return 1
        pip3 install podman-compose || return 1
      fi
      ;;
    fedora|rhel|centos|rocky|almalinux|ol|amzn)
      if command -v dnf >/dev/null 2>&1; then
        dnf install -y -q podman || return 1
        dnf install -y -q podman-compose >/dev/null 2>&1 || true
      elif command -v yum >/dev/null 2>&1; then
        yum install -y -q podman || return 1
        yum install -y -q podman-compose >/dev/null 2>&1 || true
      else
        mihomo_podman_log "当前系统缺少 dnf/yum，无法自动安装 Podman"
        return 1
      fi
      ;;
    *)
      mihomo_podman_log "仅支持 ubuntu/debian/fedora/rhel/centos/rocky/almalinux/ol/amzn 自动安装"
      return 1
      ;;
  esac

  mihomo_podman_compose_ok
}

mihomo_ensure_podman_engine() {
  [ "${MIHOMO_SKIP_PODMAN_ENSURE:-0}" = "1" ] && return 0
  mihomo_podman_compose_ok && return 0

  case "$(uname -s 2>/dev/null || true)" in
    Linux) ;;
    Darwin) mihomo_podman_log "请安装 Podman 并确保 podman compose 或 podman-compose 可用"; return 1 ;;
    *) mihomo_podman_log "当前平台不支持自动安装 Podman"; return 1 ;;
  esac

  if [ "${EUID:-0}" -ne 0 ]; then
    if command -v sudo >/dev/null 2>&1 && sudo -n true 2>/dev/null; then
      sudo env MIHOMO_PODMAN_PREREQ_INC="${BASH_SOURCE[0]}" \
        bash -c 'set -euo pipefail; . "$MIHOMO_PODMAN_PREREQ_INC"; mihomo_install_podman_linux'
      return $?
    fi
    mihomo_podman_log "需要 root 或免密 sudo"
    return 1
  fi

  mihomo_install_podman_linux
}
