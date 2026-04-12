#!/usr/bin/env bash
set -euo pipefail

AGENT="${1:?agent required: codex|claude}"
MODEL="${2:-}"
REASONING="${3:-medium}"
PROMPT_FILE="${4:?prompt file required}"

if [[ ! -f "$PROMPT_FILE" ]]; then
  echo "Prompt file not found: $PROMPT_FILE" >&2
  exit 1
fi

PROMPT="$(cat "$PROMPT_FILE")"

case "$AGENT" in
  codex)
    exec codex exec --full-auto --model "${MODEL:-gpt-5.3-codex}" -c "model_reasoning_effort=${REASONING}" "$PROMPT"
    ;;
  claude)
    exec claude --permission-mode bypassPermissions --print --model "${MODEL:-claude-opus-4.5}" "$PROMPT"
    ;;
  *)
    echo "Unsupported agent: $AGENT" >&2
    exit 1
    ;;
esac
