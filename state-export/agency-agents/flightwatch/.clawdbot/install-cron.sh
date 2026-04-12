#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CHECK_CMD="*/10 * * * * cd $ROOT_DIR && python3 ./.clawdbot/check-agents.py >> /tmp/clawdbot-check.log 2>&1"
CLEAN_CMD="17 3 * * * cd $ROOT_DIR && ./.clawdbot/cleanup.sh >> /tmp/clawdbot-cleanup.log 2>&1"

TMP="$(mktemp)"
(crontab -l 2>/dev/null || true; echo "$CHECK_CMD"; echo "$CLEAN_CMD") | awk '!seen[$0]++' > "$TMP"
crontab "$TMP"
rm -f "$TMP"

echo "Installed cron jobs:"
crontab -l | grep -E 'clawdbot-check|clawdbot-cleanup|check-agents.py|\.clawdbot/cleanup.sh' || true
