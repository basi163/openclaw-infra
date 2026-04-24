#!/usr/bin/env bash
set -euo pipefail

OPENCLAW_BIN="${OPENCLAW_BIN:-/home/linuxbrew/.linuxbrew/bin/openclaw}"
OPENCLAW_HOME="${OPENCLAW_HOME:-/home/openclaw}"
SYSTEMD_UNIT="${SYSTEMD_UNIT:-openclaw-gateway.service}"
MAX_HEALTH_RETRIES="${MAX_HEALTH_RETRIES:-5}"
HEALTH_RETRY_SLEEP="${HEALTH_RETRY_SLEEP:-3}"

if [[ ${EUID} -ne 0 ]]; then
  echo "Run as root."
  exit 1
fi

run_as_openclaw() {
  su - openclaw -s /bin/bash -c "cd '$OPENCLAW_HOME' && $*"
}

echo "== doctor --deep =="
run_as_openclaw "'$OPENCLAW_BIN' doctor --deep --non-interactive" || true

echo "== restart gateway service =="
systemctl restart "$SYSTEMD_UNIT"
sleep 3
systemctl status "$SYSTEMD_UNIT" --no-pager | sed -n '1,40p'

echo "== status --deep =="
run_as_openclaw "'$OPENCLAW_BIN' status --deep --json"

echo "== health retries =="
ok=0
for i in $(seq 1 "$MAX_HEALTH_RETRIES"); do
  echo "health attempt: $i/$MAX_HEALTH_RETRIES"
  if run_as_openclaw "'$OPENCLAW_BIN' health --json"; then
    ok=1
    break
  fi
  sleep "$HEALTH_RETRY_SLEEP"
done

if [[ "$ok" -ne 1 ]]; then
  echo "Health checks failed after retries."
  exit 1
fi

echo "== recent gateway logs =="
journalctl -u "$SYSTEMD_UNIT" -n 80 --no-pager

echo "Post-update checks completed."
