#!/usr/bin/env bash

set -euo pipefail

MODEL_NAME="${MODEL_NAME:-Qwen/Qwen1.5-MoE-A2.7B-Chat}"
ENDPOINT_URL="${ENDPOINT_URL:-http://127.0.0.1:8000/v1/chat/completions}"
REQUESTS_PER_LEVEL="${REQUESTS_PER_LEVEL:-80}"
MAX_TOKENS="${MAX_TOKENS:-256}"
CONCURRENCY_LEVELS="${CONCURRENCY_LEVELS:-1 2 4 8 16 32}"
RESULT_DIR="${RESULT_DIR:-/opt/linode-moe/results}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

mkdir -p "${RESULT_DIR}"
STAMP="$(date +%Y%m%d-%H%M%S)"
CSV_FILE="${RESULT_DIR}/summary-${STAMP}.csv"

echo "concurrency,requests,success_rate,tokens_per_second,p50_latency_s,p95_latency_s" >"${CSV_FILE}"

for c in ${CONCURRENCY_LEVELS}; do
  OUT_JSON="${RESULT_DIR}/bench-c${c}-${STAMP}.json"
  echo "Running benchmark for concurrency=${c} ..."
  /opt/linode-moe/.venv/bin/python "${SCRIPT_DIR}/benchmark_openai.py" \
    --url "${ENDPOINT_URL}" \
    --model "${MODEL_NAME}" \
    --concurrency "${c}" \
    --requests "${REQUESTS_PER_LEVEL}" \
    --max-tokens "${MAX_TOKENS}" \
    --output "${OUT_JSON}"

  line="$(jq -r '[.concurrency,.requests,.success_rate,.completion_tokens_per_second,.p50_latency_seconds,.p95_latency_seconds] | @csv' "${OUT_JSON}")"
  echo "${line}" >>"${CSV_FILE}"
done

echo
echo "Benchmark sweep complete."
echo "JSON artifacts: ${RESULT_DIR}"
echo "CSV summary: ${CSV_FILE}"
