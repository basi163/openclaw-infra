#!/usr/bin/env bash
set -euo pipefail

# Download + decrypt backup from GitHub release
# Usage: bash scripts/restore-from-release.sh backup-YYYYmmdd-HHMMSS

TAG="${1:-}"
if [[ -z "$TAG" ]]; then
  echo "Usage: $0 <release-tag>"
  exit 1
fi

OPENCLAW_BIN="/home/linuxbrew/.linuxbrew/bin/openclaw"
GH_BIN="$(command -v gh)"
REPO="${GITHUB_BACKUP_REPO:-basi163/openclaw-infra}"
WORK_DIR="${WORK_DIR:-$HOME/openclaw-restore}"

if [[ -f "$HOME/.openclaw/.backup-release.env" ]]; then
  # shellcheck disable=SC1090
  source "$HOME/.openclaw/.backup-release.env"
fi

if [[ -z "${OPENCLAW_BACKUP_PASSPHRASE:-}" ]]; then
  echo "OPENCLAW_BACKUP_PASSPHRASE is not set"
  exit 1
fi

mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

$GH_BIN release download "$TAG" --repo "$REPO" --pattern "*.enc" --pattern "*.sha256" --clobber

ENC_FILE="$(ls -1 *.enc | head -n1)"
SHA_FILE="$(ls -1 *.sha256 | head -n1)"

sha256sum -c "$SHA_FILE"

OUT_TAR="${ENC_FILE%.enc}"
openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 \
  -in "$ENC_FILE" \
  -out "$OUT_TAR" \
  -pass env:OPENCLAW_BACKUP_PASSPHRASE

$OPENCLAW_BIN backup verify "$OUT_TAR"

echo "decrypted archive ready: $WORK_DIR/$OUT_TAR"
echo "Next: stop services, unpack archive to /, then start gateway."
