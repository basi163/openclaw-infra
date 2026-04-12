#!/usr/bin/env bash
set -euo pipefail

REAL_OPENCLAW_BIN="${REAL_OPENCLAW_BIN:-/home/linuxbrew/.linuxbrew/bin/openclaw-real}"
GATEWAY_UNIT="${OPENCLAW_GATEWAY_SYSTEM_UNIT:-openclaw-gateway.service}"

if [[ ! -x "$REAL_OPENCLAW_BIN" ]]; then
  echo "openclaw wrapper error: missing real binary at $REAL_OPENCLAW_BIN" >&2
  exit 127
fi

if [[ "${1-}" == "gateway" ]] && [[ "${2-}" == "restart" ]]; then
  if [[ ${EUID} -eq 0 ]]; then
    /usr/bin/systemctl restart "$GATEWAY_UNIT"
  else
    sudo -n /usr/bin/systemctl restart "$GATEWAY_UNIT"
  fi
  echo "Gateway service restarted."
  exit 0
fi

exec "$REAL_OPENCLAW_BIN" "$@"
