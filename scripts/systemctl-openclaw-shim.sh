#!/usr/bin/env bash
set -euo pipefail

# openclaw-gateway-compat-shim
# Route OpenClaw's systemctl calls for the system-managed gateway service
# away from unavailable user-systemd DBus and through a minimal sudo policy.

REAL_SYSTEMCTL="/usr/bin/systemctl"
GATEWAY_UNIT="${OPENCLAW_GATEWAY_SYSTEM_UNIT:-openclaw-gateway.service}"
SYSTEM_UNIT_PATHS=(
  "/etc/systemd/system/$GATEWAY_UNIT"
  "/usr/lib/systemd/system/$GATEWAY_UNIT"
  "/lib/systemd/system/$GATEWAY_UNIT"
)

if [[ ! -x "$REAL_SYSTEMCTL" ]]; then
  echo "systemctl shim error: missing $REAL_SYSTEMCTL" >&2
  exit 127
fi

current_user="$(id -un 2>/dev/null || true)"
if [[ "$current_user" != "openclaw" ]]; then
  exec "$REAL_SYSTEMCTL" "$@"
fi

gateway_unit_exists=0
for candidate in "${SYSTEM_UNIT_PATHS[@]}"; do
  if [[ -f "$candidate" ]]; then
    gateway_unit_exists=1
    break
  fi
done
if (( gateway_unit_exists == 0 )); then
  exec "$REAL_SYSTEMCTL" "$@"
fi

original_args=("$@")
user_scope=0
filtered_args=()
for arg in "${original_args[@]}"; do
  if [[ "$arg" == "--user" ]]; then
    user_scope=1
    continue
  fi
  filtered_args+=("$arg")
done

action="${filtered_args[0]-}"
unit="${filtered_args[1]-}"
is_gateway_unit=0
if [[ "$unit" == "$GATEWAY_UNIT" ]]; then
  is_gateway_unit=1
fi

if (( user_scope == 1 )) && [[ "$action" == "status" ]] && [[ ${#filtered_args[@]} -eq 1 ]]; then
  exec "$REAL_SYSTEMCTL" status "$GATEWAY_UNIT"
fi

if (( is_gateway_unit == 1 )); then
  case "$action" in
    is-enabled|show|status)
      exec "$REAL_SYSTEMCTL" "${filtered_args[@]}"
      ;;
    restart|start|stop)
      exec sudo -n "$REAL_SYSTEMCTL" "$action" "$GATEWAY_UNIT"
      ;;
  esac
fi

exec "$REAL_SYSTEMCTL" "$@"
