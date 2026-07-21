#!/usr/bin/env bash

set -euo pipefail

if [[ ! -f .app.pid ]]; then
  echo "No .app.pid file found. App may not be running."
  exit 0
fi

APP_PID="$(cat .app.pid)"

if kill -0 "$APP_PID" >/dev/null 2>&1; then
  kill "$APP_PID"
  echo "Stopped app process $APP_PID"
else
  echo "Process $APP_PID not running"
fi

rm -f .app.pid
