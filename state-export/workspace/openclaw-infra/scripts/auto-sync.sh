#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

LOCK_DIR="${TMPDIR:-/tmp}/openclaw-infra-autosync.lock"
if ! mkdir "$LOCK_DIR" 2>/dev/null; then
  echo "autosync already running"
  exit 0
fi
trap 'rmdir "$LOCK_DIR"' EXIT

bash scripts/export-config.sh
bash scripts/sync-to-github.sh
