#!/usr/bin/env bash
set -e

# Debug helper: inspect containers, API endpoints, and core config fields.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/common-env.sh"

BASE="$(api_base_url)"
AUTH="$(auth_header)"

echo "[1] 容器状态"
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | rg 'mihomo-aio|NAMES' || true

echo "\n[2] API 可用性"
for path in /version /proxies /connections; do
  code=$(curl --noproxy "*" -s -o /tmp/mh_dbg.txt -w "%{http_code}" -H "$AUTH" "${BASE}${path}" || true)
  echo "${path} -> HTTP ${code}"
  if [ "$code" != "200" ]; then
    sed -n '1,20p' /tmp/mh_dbg.txt || true
  fi
done

echo "\n[3] 核心日志 tail"
docker logs --tail 80 mihomo-aio-core || true

echo "\n[4] 当前配置关键字段"
docker exec mihomo-aio-core sh -lc "grep -E '^(allow-lan|mixed-port|external-controller|secret):' /etc/mihomo/config.yaml /var/lib/mihomo/config.yaml 2>/dev/null || true"
