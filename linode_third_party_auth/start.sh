#!/usr/bin/env bash

set -euo pipefail

echo "Starting Linode third-party auth demo"

if [[ ! -f .env ]]; then
  echo "Missing .env file"
  echo "Run: cp .env.example .env"
  exit 1
fi

mkdir -p data

read_env_value() {
  local key="$1"
  local value
  value=$(awk -F= -v k="$key" '$1==k {sub(/^[^=]*=/, ""); print; exit}' .env | tr -d '\r')
  value="${value%\"}"
  value="${value#\"}"
  value="${value%\'}"
  value="${value#\'}"
  printf '%s' "$value"
}

APP_HOST="$(read_env_value HOST)"
APP_PORT="$(read_env_value PORT)"

if [[ -z "$APP_HOST" ]]; then APP_HOST="127.0.0.1"; fi
if [[ -z "$APP_PORT" ]]; then APP_PORT="3000"; fi

node app.js &
APP_PID=$!
echo "$APP_PID" > .app.pid

echo "App started on http://${APP_HOST}:${APP_PORT}"
echo "PID: $APP_PID"
echo "Open: http://${APP_HOST}:${APP_PORT}"
