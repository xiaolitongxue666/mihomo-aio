#!/usr/bin/env bash
set -e

# List candidate proxies and print measured latency values.
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

echo "策略组: ${GROUP}"
echo "--- 节点延迟(ms) ---"
while IFS= read -r name; do
  [ -n "$name" ] || continue
  enc=$(url_encode "$name")
  resp=$(curl --noproxy "*" -s -H "$AUTH" "${BASE}/proxies/${enc}/delay?url=${DELAY_URL}&timeout=${TIMEOUT_MS}") || true
  delay=$(echo "$resp" | sed -n 's/.*"delay":\s*\([0-9]*\).*/\1/p')
  [ -n "$delay" ] || delay="-"
  printf "%-50s %s ms\n" "$name" "$delay"
done <<< "$names"
