#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OPENCLAW_BIN="${OPENCLAW_BIN:-/home/linuxbrew/.linuxbrew/bin/openclaw}"
OPENCLAW_HOME="${OPENCLAW_HOME:-/home/openclaw}"
OPENCLAW_STABLE_VERSION="${OPENCLAW_STABLE_VERSION:-2026.4.12}"
OPENCLAW_NPM_SPEC="${OPENCLAW_NPM_SPEC:-openclaw@${OPENCLAW_STABLE_VERSION}}"
OPENCLAW_NPM_PREFIX="${OPENCLAW_NPM_PREFIX:-/home/linuxbrew/.linuxbrew}"
STATUS_TMP="$(mktemp)"
trap 'rm -f "$STATUS_TMP"' EXIT

if [[ ${EUID} -ne 0 ]]; then
  echo "Run as root."
  exit 1
fi

bash "$ROOT/scripts/install-openclaw-gateway-compat.sh"

before_version="$(
  sudo -u openclaw -H bash -lc "cd '$OPENCLAW_HOME' && '$OPENCLAW_BIN' --version" 2>/dev/null | tr -d '\r' || true
)"
if [[ -z "$before_version" ]]; then
  before_version="unavailable"
fi
echo "Before update: $before_version"

echo "Installing $OPENCLAW_NPM_SPEC into $OPENCLAW_NPM_PREFIX ..."
npm install -g "$OPENCLAW_NPM_SPEC" --prefix "$OPENCLAW_NPM_PREFIX" --force
bash "$ROOT/scripts/install-openclaw-gateway-compat.sh"

if [[ ! -x "$OPENCLAW_BIN" ]]; then
  echo "OpenClaw binary is still missing after reinstall: $OPENCLAW_BIN"
  exit 1
fi

after_version="$(sudo -u openclaw -H bash -lc "cd '$OPENCLAW_HOME' && '$OPENCLAW_BIN' --version" | tr -d '\r')"
echo "After update: $after_version"

sudo -u openclaw -H bash -lc "cd '$OPENCLAW_HOME' && '$OPENCLAW_BIN' status --json" >"$STATUS_TMP"

before_pid="$(
node -e '
const fs = require("node:fs");
const status = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
const gw = status.gatewayService || {};
const runtime = gw.runtime || {};
if (runtime.status !== "running") {
  console.error("Gateway service is not running after update.");
  process.exit(1);
}
console.log(`Gateway service runtime: ${runtime.status} pid=${runtime.pid ?? "n/a"} state=${runtime.state ?? "n/a"}`);
process.stderr.write(`Gateway service runtime: ${runtime.status} pid=${runtime.pid ?? "n/a"} state=${runtime.state ?? "n/a"}\n`);
process.stdout.write(String(runtime.pid ?? ""));
' "$STATUS_TMP"
)"

restart_output="$(sudo -u openclaw -H bash -lc "cd '$OPENCLAW_HOME' && '$OPENCLAW_BIN' gateway restart" | tr -d '\r')"
echo "$restart_output"

if ! grep -Eq 'restarted|restart scheduled' <<<"$restart_output"; then
  echo "Gateway restart smoke test failed."
  exit 1
fi

sleep 3
sudo -u openclaw -H bash -lc "cd '$OPENCLAW_HOME' && '$OPENCLAW_BIN' status --json" >"$STATUS_TMP"

after_pid="$(
node -e '
const fs = require("node:fs");
const status = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
const gw = status.gatewayService || {};
const runtime = gw.runtime || {};
if (runtime.status !== "running") {
  console.error("Gateway service is not healthy after restart smoke test.");
  process.exit(1);
}
process.stderr.write(`Gateway service healthy after smoke test: pid=${runtime.pid ?? "n/a"} state=${runtime.state ?? "n/a"}\n`);
process.stdout.write(String(runtime.pid ?? ""));
' "$STATUS_TMP"
)"

if [[ -n "$before_pid" ]] && [[ -n "$after_pid" ]] && [[ "$before_pid" == "$after_pid" ]]; then
  echo "Gateway restart smoke test failed: PID did not change ($before_pid)."
  exit 1
fi

journalctl -u openclaw-gateway.service -n 20 --no-pager

echo "OpenClaw update workflow completed successfully."
