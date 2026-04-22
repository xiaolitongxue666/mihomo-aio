#!/usr/bin/env bash
set -e

# Pull latest subscription config and hot-reload mihomo in place.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/common-env.sh"

[ -f "${ROOT_DIR}/.env" ] || { echo "缺少 .env"; exit 1; }
[ -n "${RAW_SUB_URL}" ] || { echo "RAW_SUB_URL 为空"; exit 1; }

sedi() {
  if sed --version >/dev/null 2>&1; then
    sed -i "$@"
  else
    sed -i "" "$@"
  fi
}

url_encode() {
  echo "$1" | sed -e 's/%/%25/g' \
    -e 's/ /%20/g' -e 's/!/%21/g' -e 's/"/%22/g' -e 's/#/%23/g' -e 's/\$/%24/g' \
    -e 's/&/%26/g' -e "s/'/%27/g" -e 's/(/%28/g' -e 's/)/%29/g' -e 's/\*/%2A/g' \
    -e 's/+/%2B/g' -e 's/,/%2C/g' -e 's#/#%2F#g' -e 's/:/%3A/g' -e 's/;/%3B/g' \
    -e 's/=/%3D/g' -e 's/?/%3F/g' -e 's/@/%40/g' -e 's/\[/%5B/g' -e 's/\]/%5D/g'
}

encoded=$(url_encode "${RAW_SUB_URL}")
SUB_TARGET="${SUBCONVERTER_TARGET:-clashmeta}"
SUB_TEMPLATE="${SUBCONVERTER_TEMPLATE:-clash.meta}"
AUTH="$(auth_header)"
api="http://127.0.0.1:${SUBCONVERTER_HOST_PORT}/sub?target=${SUB_TARGET}&config=${SUB_TEMPLATE}&url=${encoded}"

tmp_file=$(mktemp)
trap 'rm -f "$tmp_file"' EXIT

curl --noproxy "*" -fsSL "$api" -o "$tmp_file"
[ -s "$tmp_file" ] || { echo "订阅转换结果为空"; exit 1; }


# 规范关键字段，避免订阅自带配置覆盖控制面与端口
if grep -q '^allow-lan:' "$tmp_file"; then
  sedi 's/^allow-lan:.*/allow-lan: true/' "$tmp_file"
else
  sedi '1i\\
allow-lan: true' "$tmp_file"
fi

if grep -q '^mixed-port:' "$tmp_file"; then
  sedi "s/^mixed-port:.*/mixed-port: ${MIXED_PORT}/" "$tmp_file"
else
  printf "\nmixed-port: %s\n" "${MIXED_PORT}" >> "$tmp_file"
fi

if grep -q '^external-controller:' "$tmp_file"; then
  sedi "s|^external-controller:.*|external-controller: 0.0.0.0:${EXTERNAL_CONTROLLER_PORT}|" "$tmp_file"
else
  printf "external-controller: 0.0.0.0:%s\n" "${EXTERNAL_CONTROLLER_PORT}" >> "$tmp_file"
fi

if grep -q '^secret:' "$tmp_file"; then
  sedi "s/^secret:.*/secret: ${SECRET}/" "$tmp_file"
else
  printf "secret: %s\n" "${SECRET}" >> "$tmp_file"
fi
docker cp "$tmp_file" mihomo-aio-core:/etc/mihomo/config.yaml
docker cp "$tmp_file" mihomo-aio-core:/var/lib/mihomo/config.yaml

status=$(curl --noproxy "*" -s -o /dev/null -w "%{http_code}" -X PUT "$(api_base_url)/configs" -H "$AUTH" -H "Content-Type: application/json" -d '{"path":"/var/lib/mihomo/config.yaml"}')
if [ "$status" = "204" ] || [ "$status" = "200" ]; then
  ./scripts/sync-dashboard-config.sh >/dev/null 2>&1 || true
  echo "订阅已更新并热重载"
else
  echo "重载失败 HTTP ${status}"
  exit 1
fi
