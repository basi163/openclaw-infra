#!/usr/bin/env bash
set -euo pipefail

DASH_DIR="/home/openclaw/.openclaw/workspace/assistant-dashboard"
PID_FILE="/tmp/assistant-dashboard.pid"
LOG_FILE="/tmp/assistant-dashboard.log"
URL="http://127.0.0.1:3030/api/status"

is_healthy() {
  curl -fsS --max-time 3 "$URL" >/dev/null 2>&1
}

start_dashboard() {
  cd "$DASH_DIR"
  nohup node server.js >>"$LOG_FILE" 2>&1 &
  echo $! >"$PID_FILE"
}

if is_healthy; then
  exit 0
fi

if [[ -f "$PID_FILE" ]]; then
  PID="$(cat "$PID_FILE" || true)"
  if [[ -n "${PID:-}" ]] && kill -0 "$PID" 2>/dev/null; then
    kill "$PID" 2>/dev/null || true
    sleep 1
  fi
fi

start_dashboard
sleep 1
is_healthy || exit 1
