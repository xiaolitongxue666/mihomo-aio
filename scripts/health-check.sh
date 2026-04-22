#!/usr/bin/env bash
set -e

# Basic runtime checks for API, dashboard, and proxy chain.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/common-env.sh"

AUTH="$(auth_header)"
BASE="$(api_base_url)"
DASHBOARD_URL="$(dashboard_url)"

echo "[1/4] 检查 external-controller 就绪: ${BASE}"
for i in $(seq 1 30); do
  if curl --noproxy "*" -fsS -H "$AUTH" "${BASE}/version" >/dev/null 2>&1; then
    echo "  - external-controller 已就绪"
    break
  fi
  sleep 1
  if [ "$i" -eq 30 ]; then
    echo "  - external-controller 未就绪"
    exit 1
  fi
done

echo "[2/4] 检查 proxies 接口"
curl --noproxy "*" -fsS -H "$AUTH" "${BASE}/proxies" >/dev/null
echo "  - proxies 接口可访问"

echo "[3/4] 检查 dashboard: ${DASHBOARD_URL}"
curl --noproxy "*" -fsS "${DASHBOARD_URL}" >/dev/null
echo "  - dashboard 可访问"

echo "[4/4] 检查代理链路: 127.0.0.1:${ALL_PROXY_PORT}"
if curl --noproxy "*" -x "http://127.0.0.1:${ALL_PROXY_PORT}" -s --connect-timeout 8 "http://ip-api.com/json/" >/dev/null; then
  echo "  - 代理链路可用"
else
  echo "  - 代理请求未通过（可能节点不可用或订阅不可达）"
fi

echo "health-check 完成"
