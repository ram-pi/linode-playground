#!/usr/bin/env bash

set -euo pipefail

METRICS_URL="${METRICS_URL:-http://127.0.0.1:8000/metrics}"

echo "Querying metrics from ${METRICS_URL}"
echo

if ! curl -fsS "${METRICS_URL}" >/tmp/vllm-metrics.txt; then
  echo "Unable to fetch metrics endpoint. Is vLLM running and bound to localhost:8000?"
  exit 1
fi

echo "Possible routing/load-balance related metrics:"
grep -Ei 'expert|router|gate|moe|dropped|overflow|queue' /tmp/vllm-metrics.txt || true

echo
echo "GPU utilization snapshot:"
nvidia-smi --query-gpu=index,name,utilization.gpu,utilization.memory,memory.used,memory.total --format=csv

echo
echo "Tip: Compare these metrics under DP and EP runs at the same concurrency profile."
