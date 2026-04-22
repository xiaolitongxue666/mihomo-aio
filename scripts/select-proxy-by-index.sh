#!/usr/bin/env bash
set -e

# Interactive proxy switcher: choose proxy by index and apply via API.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck disable=SC1091
. "${SCRIPT_DIR}/common-env.sh"

LIMIT="${1:-20}"
BASE="$(api_base_url)"
AUTH="$(auth_header)"
DELAY_URL="https://www.gstatic.com/generate_204"
TIMEOUT_MS=10000

json=$(curl --noproxy "*" -s -H "$AUTH" "${BASE}/proxies") || true
if [ -z "$json" ] || [[ ! "$json" =~ "proxies" ]]; then
  echo "无法连接 API: ${BASE}"
  exit 1
fi

before_all="${json%%\"all\":[*}"
GROUP=$(echo "$before_all" | grep -oE '"[^"]+":\s*\{' | tail -1 | sed 's/":.*//;s/"//g')
[ -n "$GROUP" ] || { echo "未解析到策略组"; exit 1; }

after_all="${json#*\"all\":[}"
segment="${after_all%%]*}"
names=$(echo "$segment" | sed 's/","/\
/g' | sed 's/^"//;s/"$//' | grep -v -E '^(DIRECT|REJECT)$')
[ -n "$names" ] || { echo "未解析到节点"; exit 1; }

if [[ "$LIMIT" =~ ^[0-9]+$ ]] && [ "$LIMIT" -gt 0 ]; then
  names=$(echo "$names" | head -n "$LIMIT")
fi

url_encode() {
  echo "$1" | sed -e 's/%/%25/g' -e 's/ /%20/g' -e 's/!/%21/g' -e 's/"/%22/g' -e 's/#/%23/g' \
    -e 's/&/%26/g' -e "s/'/%27/g" -e 's/(/%28/g' -e 's/)/%29/g' -e 's/\*/%2A/g' -e 's/+/%2B/g' \
    -e 's/,/%2C/g' -e 's#/#%2F#g' -e 's/:/%3A/g' -e 's/;/%3B/g' -e 's/=/%3D/g' -e 's/?/%3F/g' \
    -e 's/@/%40/g' -e 's/\[/%5B/g' -e 's/\]/%5D/g'
}

NAMES_ARR=()
while IFS= read -r line; do
  [ -n "$line" ] && NAMES_ARR+=("$line")
done <<< "$names"
N=${#NAMES_ARR[@]}
[ "$N" -gt 0 ] || { echo "无可选节点"; exit 1; }

echo "策略组: ${GROUP}"
echo "--- 选择节点 (1-${N}) ---"
for ((i=0;i<N;i++)); do
  name="${NAMES_ARR[$i]}"
  enc=$(url_encode "$name")
  resp=$(curl --noproxy "*" -s -H "$AUTH" "${BASE}/proxies/${enc}/delay?url=${DELAY_URL}&timeout=${TIMEOUT_MS}") || true
  delay=$(echo "$resp" | sed -n 's/.*"delay":\s*\([0-9]*\).*/\1/p')
  [ -n "$delay" ] || delay="-"
  printf "%3d. %-45s %s ms\n" "$((i+1))" "$name" "$delay"
done

read -r -p "输入序号(0取消): " num
num="${num// /}"
[ "$num" = "0" ] && exit 0
if ! [[ "$num" =~ ^[0-9]+$ ]] || [ "$num" -lt 1 ] || [ "$num" -gt "$N" ]; then
  echo "输入无效"
  exit 1
fi

selected="${NAMES_ARR[$((num-1))]}"
escaped=$(echo "$selected" | sed 's/\\/\\\\/g;s/"/\\"/g')
body="{\"name\":\"${escaped}\"}"
status=$(curl --noproxy "*" -s -o /dev/null -w "%{http_code}" -X PUT -H "$AUTH" -H "Content-Type: application/json" -d "$body" "${BASE}/proxies/${GROUP}")
if [ "$status" = "204" ] || [ "$status" = "200" ]; then
  echo "已切换到: ${selected}"
else
  echo "切换失败 HTTP ${status}"
  exit 1
fi
