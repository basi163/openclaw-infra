#!/usr/bin/env bash
set -euo pipefail

# bootstrap for new server
if ! command -v openclaw >/dev/null 2>&1; then
  echo "OpenClaw is not installed. Install first: https://openclaw.ai"
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# ensure repo configured
if [ ! -d .git ]; then
  git init -b master
fi

git config user.name "OpenClaw Assistant"
git config user.email "assistant@openclaw.local"

bash scripts/export-config.sh || true

bash scripts/install-autosync.sh
bash scripts/install-openclaw-gateway-compat.sh

echo "bootstrap done"
