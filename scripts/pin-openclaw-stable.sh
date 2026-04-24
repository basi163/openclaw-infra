#!/usr/bin/env bash
set -euo pipefail

OPENCLAW_STABLE_VERSION="${OPENCLAW_STABLE_VERSION:-2026.4.12}"
OPENCLAW_NPM_PREFIX="${OPENCLAW_NPM_PREFIX:-/home/linuxbrew/.linuxbrew}"
OPENCLAW_BIN="${OPENCLAW_BIN:-/home/linuxbrew/.linuxbrew/bin/openclaw}"
OPENCLAW_HOME="${OPENCLAW_HOME:-/home/openclaw}"

if [[ ${EUID} -ne 0 ]]; then
  echo "Run as root."
  exit 1
fi

echo "Pinning OpenClaw to ${OPENCLAW_STABLE_VERSION} ..."
npm install -g "openclaw@${OPENCLAW_STABLE_VERSION}" --prefix "$OPENCLAW_NPM_PREFIX" --force

if [[ ! -x "$OPENCLAW_BIN" ]]; then
  echo "OpenClaw binary not found after install: $OPENCLAW_BIN"
  exit 1
fi

echo "Installed version:"
sudo -u openclaw -H bash -lc "cd '$OPENCLAW_HOME' && '$OPENCLAW_BIN' --version"
