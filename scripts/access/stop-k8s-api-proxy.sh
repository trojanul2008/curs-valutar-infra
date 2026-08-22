#!/usr/bin/env bash
set -euo pipefail

readonly STATE_DIR="${RUNNER_TEMP:-/tmp}"
readonly PID_FILE="${STATE_DIR}/cloudflared-k8s-api.pid"

if [[ ! -f "$PID_FILE" ]]; then
  echo "No Kubernetes API Cloudflare proxy PID file found."
  exit 0
fi

PID="$(cat "$PID_FILE")"

if kill -0 "$PID" 2>/dev/null; then
  echo "Stopping Kubernetes API Cloudflare proxy."

  kill "$PID" 2>/dev/null || true

  for _ in $(seq 1 10); do
    if ! kill -0 "$PID" 2>/dev/null; then
      break
    fi

    sleep 1
  done

  if kill -0 "$PID" 2>/dev/null; then
    echo "Cloudflare proxy did not stop gracefully; terminating it."
    kill -KILL "$PID" 2>/dev/null || true
  fi
fi

rm -f "$PID_FILE"

echo "Kubernetes API Cloudflare proxy stopped."
