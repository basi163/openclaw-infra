#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/state-export"
mkdir -p "$OUT"

OPENCLAW_JSON="$HOME/.openclaw/openclaw.json"

# 1) redacted openclaw config
python3 - <<'PY'
import json, pathlib
src = pathlib.Path.home()/'.openclaw'/'openclaw.json'
out = pathlib.Path('/home/openclaw/.openclaw/workspace/openclaw-infra/state-export/openclaw.json.redacted')
obj = json.loads(src.read_text())
SENSITIVE = {'token','secret','password','apiKey','api_key','clientSecret','accessToken','refreshToken'}

def redact(x):
    if isinstance(x, dict):
        o = {}
        for k,v in x.items():
            if any(s.lower() in k.lower() for s in SENSITIVE):
                o[k] = '***REDACTED***'
            else:
                o[k] = redact(v)
        return o
    if isinstance(x, list):
        return [redact(i) for i in x]
    return x

out.parent.mkdir(parents=True, exist_ok=True)
out.write_text(json.dumps(redact(obj), ensure_ascii=False, indent=2)+"\n")
PY

# 2) agents inventory
/home/linuxbrew/.linuxbrew/bin/openclaw agents list > "$OUT/agents-list.txt" || true
/home/linuxbrew/.linuxbrew/bin/openclaw status --json > "$OUT/status.json" || true

# 3) copy important config trees (without heavy runtime dirs)
mkdir -p "$OUT/agency-agents" "$OUT/workspace"
rsync -a --delete \
  --exclude '.git/' \
  --exclude 'node_modules/' \
  --exclude '.next/' \
  --exclude '.openclaw/' \
  --exclude 'sessions/' \
  --exclude 'memory/' \
  "$HOME/.openclaw/agency-agents/" "$OUT/agency-agents/"

# optional workspace snapshots of infra projects only
for p in assistant-dashboard openclaw-infra; do
  if [ -d "$HOME/.openclaw/workspace/$p" ]; then
    rsync -a --delete \
      --exclude '.git/' \
      --exclude 'node_modules/' \
      --exclude '.next/' \
      "$HOME/.openclaw/workspace/$p/" "$OUT/workspace/$p/"
  fi
done

echo "export complete: $OUT"
