#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SHIM_SOURCE="$ROOT/scripts/systemctl-openclaw-shim.sh"
OPENCLAW_WRAPPER_SOURCE="$ROOT/scripts/openclaw-wrapper.sh"
SHIM_TARGET="/usr/local/bin/systemctl"
OPENCLAW_BIN="/home/linuxbrew/.linuxbrew/bin/openclaw"
OPENCLAW_REAL_BIN="/home/linuxbrew/.linuxbrew/bin/openclaw-real"
SUDOERS_TARGET="/etc/sudoers.d/openclaw-gateway-systemctl"
SYSTEM_UNIT_TARGET="/etc/systemd/system/openclaw-gateway.service"
USER_UNIT_DIR="/home/openclaw/.config/systemd/user"
USER_UNIT_LINK="$USER_UNIT_DIR/openclaw-gateway.service"
MARKER="openclaw-gateway-compat-shim"

if [[ ${EUID} -ne 0 ]]; then
  echo "Run as root."
  exit 1
fi

if [[ ! -f "$SHIM_SOURCE" ]]; then
  echo "Missing shim source: $SHIM_SOURCE"
  exit 1
fi
if [[ ! -f "$OPENCLAW_WRAPPER_SOURCE" ]]; then
  echo "Missing openclaw wrapper source: $OPENCLAW_WRAPPER_SOURCE"
  exit 1
fi

if [[ -e "$SHIM_TARGET" ]] && ! grep -q "$MARKER" "$SHIM_TARGET"; then
  echo "Refusing to overwrite existing non-OpenClaw shim: $SHIM_TARGET"
  exit 1
fi

install -m 0755 "$SHIM_SOURCE" "$SHIM_TARGET"

if [[ -e "$OPENCLAW_BIN" ]] && [[ ! -L "$OPENCLAW_BIN" ]]; then
  if ! grep -q "Gateway service restarted." "$OPENCLAW_BIN"; then
    echo "Refusing to overwrite existing non-OpenClaw wrapper at $OPENCLAW_BIN"
    exit 1
  fi
fi
if [[ -L "$OPENCLAW_BIN" ]]; then
  ln -sfn "$(readlink -f "$OPENCLAW_BIN")" "$OPENCLAW_REAL_BIN"
fi
install -m 0755 "$OPENCLAW_WRAPPER_SOURCE" "$OPENCLAW_BIN"

install -d -o openclaw -g openclaw -m 0755 "$USER_UNIT_DIR"
if [[ -e "$USER_UNIT_LINK" ]] && [[ ! -L "$USER_UNIT_LINK" ]]; then
  mv "$USER_UNIT_LINK" "$USER_UNIT_LINK.bak"
fi
ln -sfn "$SYSTEM_UNIT_TARGET" "$USER_UNIT_LINK"
chown -h openclaw:openclaw "$USER_UNIT_LINK"

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
echo "  openclaw wrapper: $OPENCLAW_BIN"
echo "  openclaw real: $OPENCLAW_REAL_BIN"
echo "  sudoers: $SUDOERS_TARGET"
echo "  user-unit link: $USER_UNIT_LINK -> $SYSTEM_UNIT_TARGET"
