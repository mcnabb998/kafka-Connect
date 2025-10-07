#!/usr/bin/env bash
set -euo pipefail

PID_FILE="${CONNECT_PID_FILE:-/var/run/connect-distributed.pid}"
if [[ -f "$PID_FILE" ]]; then
  if ps -p "$(cat "$PID_FILE")" >/dev/null 2>&1; then
    exit 0
  fi
fi

if pgrep -f "connect-distributed" >/dev/null 2>&1; then
  exit 0
fi

echo "Kafka Connect process not running" >&2
exit 1
