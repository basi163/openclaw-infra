#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SWARM_DIR="$ROOT_DIR/.clawdbot"
TASKS_FILE="$SWARM_DIR/active-tasks.json"
WORKTREES_DIR="${WORKTREES_DIR:-$ROOT_DIR/.worktrees}"
LOG_DIR="$SWARM_DIR/logs"

mkdir -p "$WORKTREES_DIR" "$LOG_DIR"

ID=""
AGENT="codex"
MODEL="gpt-5.3-codex"
REASONING="high"
PROMPT=""
PROMPT_FILE=""
BASE_BRANCH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --id) ID="$2"; shift 2 ;;
    --agent) AGENT="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    --reasoning) REASONING="$2"; shift 2 ;;
    --prompt) PROMPT="$2"; shift 2 ;;
    --prompt-file) PROMPT_FILE="$2"; shift 2 ;;
    --base) BASE_BRANCH="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

[[ -n "$ID" ]] || { echo "--id is required" >&2; exit 1; }
[[ -n "$PROMPT" || -n "$PROMPT_FILE" ]] || { echo "--prompt or --prompt-file required" >&2; exit 1; }

if [[ -z "$BASE_BRANCH" ]]; then
  BASE_BRANCH="$(git -C "$ROOT_DIR" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || true)"
  BASE_BRANCH="${BASE_BRANCH:-main}"
fi

BRANCH="swarm/${ID}"
WORKTREE="$WORKTREES_DIR/$ID"
SESSION="swarm-${ID}"
LOG_FILE="$LOG_DIR/${ID}.log"

if [[ -n "$PROMPT" ]]; then
  PROMPT_FILE="$SWARM_DIR/prompts-${ID}.txt"
  printf "%s\n" "$PROMPT" > "$PROMPT_FILE"
fi

# Build default delivery requirements into prompt
echo "" >> "$PROMPT_FILE"
echo "Definition of done:" >> "$PROMPT_FILE"
echo "- Commit changes in current branch" >> "$PROMPT_FILE"
echo "- Push branch to origin" >> "$PROMPT_FILE"
echo "- Open PR with gh pr create --fill" >> "$PROMPT_FILE"

git -C "$ROOT_DIR" fetch origin "$BASE_BRANCH" >/dev/null 2>&1 || true

if [[ ! -d "$WORKTREE" ]]; then
  git -C "$ROOT_DIR" worktree add -B "$BRANCH" "$WORKTREE" "origin/$BASE_BRANCH"
fi

# Optional deps bootstrap
if [[ -f "$WORKTREE/pnpm-lock.yaml" ]]; then
  (cd "$WORKTREE" && pnpm install --frozen-lockfile || pnpm install) >>"$LOG_FILE" 2>&1 || true
elif [[ -f "$WORKTREE/package-lock.json" ]]; then
  (cd "$WORKTREE" && npm ci || npm install) >>"$LOG_FILE" 2>&1 || true
fi

if tmux has-session -t "$SESSION" 2>/dev/null; then
  tmux kill-session -t "$SESSION"
fi

CMD="cd '$WORKTREE' && '$SWARM_DIR/run-agent.sh' '$AGENT' '$MODEL' '$REASONING' '$PROMPT_FILE' >>'$LOG_FILE' 2>&1"
tmux new-session -d -s "$SESSION" "$CMD"

ROOT_DIR="$ROOT_DIR" TASKS_FILE="$TASKS_FILE" ID="$ID" SESSION="$SESSION" AGENT="$AGENT" MODEL="$MODEL" REASONING="$REASONING" WORKTREE="$WORKTREE" BRANCH="$BRANCH" LOG_FILE="$LOG_FILE" PROMPT_FILE="$PROMPT_FILE" python3 - <<'PY'
import json, time, pathlib, os
root = pathlib.Path(os.environ['ROOT_DIR'])
tasks_file = pathlib.Path(os.environ['TASKS_FILE'])
entry = {
  "id": os.environ['ID'],
  "tmuxSession": os.environ['SESSION'],
  "agent": os.environ['AGENT'],
  "model": os.environ['MODEL'],
  "reasoning": os.environ['REASONING'],
  "description": f"swarm task {os.environ['ID']}",
  "repo": root.name,
  "worktree": os.environ['WORKTREE'],
  "branch": os.environ['BRANCH'],
  "startedAt": int(time.time()*1000),
  "status": "running",
  "notifyOnComplete": True,
  "retries": 0,
  "maxRetries": 3,
  "logFile": os.environ['LOG_FILE'],
  "promptFile": os.environ['PROMPT_FILE']
}
arr = []
if tasks_file.exists():
  try:
    arr = json.loads(tasks_file.read_text())
  except Exception:
    arr = []
arr = [x for x in arr if x.get('id') != entry['id']]
arr.append(entry)
tasks_file.write_text(json.dumps(arr, ensure_ascii=False, indent=2) + "\n")
PY

echo "Spawned: $ID"
echo "Session: $SESSION"
echo "Worktree: $WORKTREE"
echo "Log: $LOG_FILE"
