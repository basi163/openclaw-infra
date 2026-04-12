#!/usr/bin/env bash
set -euo pipefail

OUT_DIR="$HOME/openclaw-backups"
mkdir -p "$OUT_DIR"

/home/linuxbrew/.linuxbrew/bin/openclaw backup create --output "$OUT_DIR" --verify

echo "backup ready in: $OUT_DIR"
