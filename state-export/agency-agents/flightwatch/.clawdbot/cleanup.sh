#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TASKS_FILE="$ROOT_DIR/.clawdbot/active-tasks.json"

ROOT_DIR="$ROOT_DIR" python3 - <<'PY'
import json, time, pathlib, subprocess, os
root = pathlib.Path(os.environ["ROOT_DIR"])
tasks_file = root / ".clawdbot" / "active-tasks.json"
if not tasks_file.exists():
  raise SystemExit(0)
arr = json.loads(tasks_file.read_text())
now = int(time.time()*1000)
keep = []
for t in arr:
  st = t.get("status")
  done_at = int(t.get("completedAt", 0) or 0)
  wt = t.get("worktree")
  # clean tasks older than 24h after completion
  if st in {"ready_for_review", "done", "failed"} and done_at and now - done_at > 24*3600*1000:
    if wt:
      subprocess.run(["git", "-C", str(root), "worktree", "remove", "--force", wt], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    continue
  keep.append(t)
tasks_file.write_text(json.dumps(keep, ensure_ascii=False, indent=2)+"\n")
subprocess.run(["git", "-C", str(root), "worktree", "prune"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
PY
