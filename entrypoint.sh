#!/usr/bin/env sh
set -eu

CONFIG_DIR="/etc/mihomo"
CONFIG_FILE="${CONFIG_DIR}/config.yaml"
RUNTIME_DIR="/var/lib/mihomo"

RAW_SUB_URL="${RAW_SUB_URL:-}"
MIXED_PORT="${MIXED_PORT:-7890}"
EXTERNAL_CONTROLLER_PORT="${EXTERNAL_CONTROLLER_PORT:-9090}"
SECRET="${SECRET:-change-me}"
SUBCONVERTER_TARGET="${SUBCONVERTER_TARGET:-clashmeta}"
SUBCONVERTER_TEMPLATE="${SUBCONVERTER_TEMPLATE:-clash.meta}"
SUBCONVERTER_HOST="${SUBCONVERTER_HOST:-subconverter}"
SUBSCRIPTION_UPDATE_INTERVAL="${SUBSCRIPTION_UPDATE_INTERVAL:-0}"

mkdir -p "${CONFIG_DIR}" "${RUNTIME_DIR}"

url_encode() {
  echo "$1" | sed -e 's/%/%25/g' \
    -e 's/ /%20/g' -e 's/!/%21/g' -e 's/"/%22/g' -e 's/#/%23/g' -e 's/\$/%24/g' \
    -e 's/&/%26/g' -e "s/'/%27/g" -e 's/(/%28/g' -e 's/)/%29/g' -e 's/\*/%2A/g' \
    -e 's/+/%2B/g' -e 's/,/%2C/g' -e 's#/#%2F#g' -e 's/:/%3A/g' -e 's/;/%3B/g' \
    -e 's/=/%3D/g' -e 's/?/%3F/g' -e 's/@/%40/g' -e 's/\[/%5B/g' -e 's/\]/%5D/g'
}

ensure_minimal_config() {
  cat > "${CONFIG_FILE}" <<CFG
allow-lan: true
mode: rule
log-level: info
mixed-port: ${MIXED_PORT}
external-controller: 0.0.0.0:${EXTERNAL_CONTROLLER_PORT}
secret: ${SECRET}
proxies: []
proxy-groups: []
rules: []
CFG
}

inject_required_keys() {
  if grep -q '^allow-lan:' "${CONFIG_FILE}"; then
    sed -i 's/^allow-lan:.*/allow-lan: true/' "${CONFIG_FILE}"
  else
    sed -i '1i allow-lan: true' "${CONFIG_FILE}"
  fi

  if grep -q '^mixed-port:' "${CONFIG_FILE}"; then
    sed -i "s/^mixed-port:.*/mixed-port: ${MIXED_PORT}/" "${CONFIG_FILE}"
  else
    printf '\nmixed-port: %s\n' "${MIXED_PORT}" >> "${CONFIG_FILE}"
  fi

  if grep -q '^external-controller:' "${CONFIG_FILE}"; then
    sed -i "s|^external-controller:.*|external-controller: 0.0.0.0:${EXTERNAL_CONTROLLER_PORT}|" "${CONFIG_FILE}"
  else
    printf 'external-controller: 0.0.0.0:%s\n' "${EXTERNAL_CONTROLLER_PORT}" >> "${CONFIG_FILE}"
  fi

  if grep -q '^secret:' "${CONFIG_FILE}"; then
    sed -i "s/^secret:.*/secret: ${SECRET}/" "${CONFIG_FILE}"
  else
    printf 'secret: %s\n' "${SECRET}" >> "${CONFIG_FILE}"
  fi
}

pull_subscription_config() {
  [ -n "${RAW_SUB_URL}" ] || return 1
  case "${RAW_SUB_URL}" in
    *example.com/subscription*|*YOUR_SUBSCRIPTION*) return 1 ;;
  esac
  encoded_url="$(url_encode "${RAW_SUB_URL}")"
  api="http://${SUBCONVERTER_HOST}:25500/sub?target=${SUBCONVERTER_TARGET}&config=${SUBCONVERTER_TEMPLATE}&url=${encoded_url}"

  attempt=1
  while [ "$attempt" -le 15 ]; do
    if curl -fsSL --connect-timeout 5 --max-time 30 "$api" -o "${CONFIG_FILE}"; then
      if [ -s "${CONFIG_FILE}" ]; then
        return 0
      fi
    fi
    attempt=$((attempt + 1))
    sleep 2
  done
  return 1
}

periodic_reload() {
  while [ "${SUBSCRIPTION_UPDATE_INTERVAL}" -gt 0 ]; do
    sleep "${SUBSCRIPTION_UPDATE_INTERVAL}"
    if pull_subscription_config; then
      inject_required_keys
      curl -sS -X PUT "http://127.0.0.1:${EXTERNAL_CONTROLLER_PORT}/configs" \
        -H "Authorization: Bearer ${SECRET}" \
        -H "Content-Type: application/json" \
        -d "{\"path\":\"${RUNTIME_DIR}/config.yaml\"}" >/dev/null 2>&1 || true
    fi
  done
}

if [ ! -s "${CONFIG_FILE}" ]; then
  if ! pull_subscription_config; then
    ensure_minimal_config
  fi
fi

inject_required_keys
cp "${CONFIG_FILE}" "${RUNTIME_DIR}/config.yaml"

if [ "${SUBSCRIPTION_UPDATE_INTERVAL}" -gt 0 ]; then
  periodic_reload &
fi

exec /usr/local/bin/mihomo -f "${CONFIG_FILE}" -d "${RUNTIME_DIR}"
