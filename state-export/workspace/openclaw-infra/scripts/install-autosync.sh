#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
AUTO_SYNC_LOG="${AUTO_SYNC_LOG:-/tmp/openclaw-infra-autosync.log}"
BACKUP_RELEASE_LOG="${BACKUP_RELEASE_LOG:-/tmp/openclaw-infra-backup-release.log}"
AUTO_SYNC_SCHEDULE="${AUTO_SYNC_SCHEDULE:-0 * * * *}"
BACKUP_RELEASE_SCHEDULE="${BACKUP_RELEASE_SCHEDULE:-35 3 * * *}"

mkdir -p "$(dirname "$AUTO_SYNC_LOG")" "$(dirname "$BACKUP_RELEASE_LOG")"

(
  crontab -l 2>/dev/null
  echo "@reboot $ROOT/scripts/auto-sync.sh >> $AUTO_SYNC_LOG 2>&1"
  echo "$AUTO_SYNC_SCHEDULE $ROOT/scripts/auto-sync.sh >> $AUTO_SYNC_LOG 2>&1"
  echo "$BACKUP_RELEASE_SCHEDULE $ROOT/scripts/backup-release.sh >> $BACKUP_RELEASE_LOG 2>&1"
) | awk '!seen[$0]++' | crontab -

echo "autosync installed"
echo "sync schedule: $AUTO_SYNC_SCHEDULE"
echo "backup release schedule: $BACKUP_RELEASE_SCHEDULE"
