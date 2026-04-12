#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SHIM_SOURCE="$ROOT/scripts/systemctl-openclaw-shim.sh"
SHIM_TARGET="/usr/local/bin/systemctl"
SUDOERS_TARGET="/etc/sudoers.d/openclaw-gateway-systemctl"
MARKER="openclaw-gateway-compat-shim"

if [[ ${EUID} -ne 0 ]]; then
  echo "Run as root."
  exit 1
fi

if [[ ! -f "$SHIM_SOURCE" ]]; then
  echo "Missing shim source: $SHIM_SOURCE"
  exit 1
fi

if [[ -e "$SHIM_TARGET" ]] && ! grep -q "$MARKER" "$SHIM_TARGET"; then
  echo "Refusing to overwrite existing non-OpenClaw shim: $SHIM_TARGET"
  exit 1
fi

install -m 0755 "$SHIM_SOURCE" "$SHIM_TARGET"

cat >"$SUDOERS_TARGET" <<'EOF'
Defaults:openclaw !requiretty
openclaw ALL=(root) NOPASSWD: /usr/bin/systemctl start openclaw-gateway.service
openclaw ALL=(root) NOPASSWD: /usr/bin/systemctl stop openclaw-gateway.service
openclaw ALL=(root) NOPASSWD: /usr/bin/systemctl restart openclaw-gateway.service
EOF

chmod 0440 "$SUDOERS_TARGET"
visudo -cf "$SUDOERS_TARGET"

echo "Installed OpenClaw gateway compatibility shim:"
echo "  shim: $SHIM_TARGET"
echo "  sudoers: $SUDOERS_TARGET"
