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

# register background autosync (developer worker)
( crontab -l 2>/dev/null; \
  echo "@reboot $ROOT/scripts/auto-sync.sh >> /tmp/developer-autosync.log 2>&1"; \
  echo "*/5 * * * * $ROOT/scripts/auto-sync.sh >> /tmp/developer-autosync.log 2>&1"; \
  echo "35 3 * * * $ROOT/scripts/backup-release.sh >> /tmp/developer-backup-release.log 2>&1" \
) | awk '!seen[$0]++' | crontab -

echo "bootstrap done"
