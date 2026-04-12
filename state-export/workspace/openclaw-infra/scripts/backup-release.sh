#!/usr/bin/env bash
set -euo pipefail

# Encrypted backup upload to GitHub Release
# Requires:
# - gh auth (repo scope)
# - OPENCLAW_BACKUP_PASSPHRASE in env or ~/.openclaw/.backup-release.env

OPENCLAW_BIN="/home/linuxbrew/.linuxbrew/bin/openclaw"
GH_BIN="$(command -v gh)"
OUT_DIR="${OUT_DIR:-$HOME/openclaw-backups}"
REPO="${GITHUB_BACKUP_REPO:-basi163/openclaw-infra}"

if [[ -f "$HOME/.openclaw/.backup-release.env" ]]; then
  # shellcheck disable=SC1090
  source "$HOME/.openclaw/.backup-release.env"
fi

if [[ -z "${OPENCLAW_BACKUP_PASSPHRASE:-}" ]]; then
  echo "OPENCLAW_BACKUP_PASSPHRASE is not set. Put it in ~/.openclaw/.backup-release.env"
  exit 1
fi
export OPENCLAW_BACKUP_PASSPHRASE

mkdir -p "$OUT_DIR"

RAW_OUT="$($OPENCLAW_BIN backup create --output "$OUT_DIR" --verify --json 2>&1 || true)"
ARCHIVE_PATH="$(RAW="$RAW_OUT" python3 - <<'PY'
import json, os, re
raw = os.environ.get('RAW', '').strip()
if not raw:
    print('')
    raise SystemExit

try:
    obj = json.loads(raw)
    print(obj.get('archivePath', ''))
    raise SystemExit
except Exception:
    pass

m = re.search(r'\{.*\}', raw, re.S)
if m:
    try:
        obj = json.loads(m.group(0))
        print(obj.get('archivePath', ''))
        raise SystemExit
    except Exception:
        pass

print('')
PY
)"

if [[ -z "$ARCHIVE_PATH" || ! -f "$ARCHIVE_PATH" ]]; then
  echo "Backup archive not found"
  echo "$RAW_OUT"
  exit 1
fi

STAMP="$(date -u +%Y%m%d-%H%M%S)"
BASE="openclaw-backup-${STAMP}"
ENC_PATH="${OUT_DIR}/${BASE}.tar.gz.enc"
SHA_PATH="${ENC_PATH}.sha256"
TAG="backup-${STAMP}"

openssl enc -aes-256-cbc -pbkdf2 -salt -iter 200000 \
  -in "$ARCHIVE_PATH" \
  -out "$ENC_PATH" \
  -pass env:OPENCLAW_BACKUP_PASSPHRASE

sha256sum "$ENC_PATH" > "$SHA_PATH"

$GH_BIN release create "$TAG" \
  "$ENC_PATH" \
  "$SHA_PATH" \
  --repo "$REPO" \
  --title "OpenClaw encrypted backup ${STAMP} UTC" \
  --notes "Automated encrypted backup snapshot."

# keep encrypted artifact, remove plain archive
rm -f "$ARCHIVE_PATH"

echo "release created: https://github.com/${REPO}/releases/tag/${TAG}"
