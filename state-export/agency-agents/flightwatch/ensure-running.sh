#!/usr/bin/env bash
set -euo pipefail

FW_DIR="/home/openclaw/.openclaw/agency-agents/flightwatch"
LOG_FILE="/tmp/flightwatch-monitor.log"
LOCK_FILE="/tmp/flightwatch-monitor.lock"

mkdir -p /tmp

{
  flock -n 9 || exit 0

  cd "$FW_DIR"
  python3 blogwatch_sync.py >>"$LOG_FILE" 2>&1
  blogwatcher scan -s >>"$LOG_FILE" 2>&1
} 9>"$LOCK_FILE"
