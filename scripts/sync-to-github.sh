#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [ ! -d .git ]; then
  git init -b master
  git config user.name "OpenClaw Assistant"
  git config user.email "assistant@openclaw.local"
fi

if ! git remote get-url origin >/dev/null 2>&1; then
  git remote add origin https://github.com/basi163/openclaw-infra.git
fi

git add -A
if git diff --cached --quiet; then
  echo "no changes"
  exit 0
fi

git commit -m "chore(infra): auto-sync $(date -u +'%Y-%m-%d %H:%M:%S UTC')"
git push -u origin "$(git branch --show-current)"
