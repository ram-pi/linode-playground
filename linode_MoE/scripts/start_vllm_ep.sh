#!/usr/bin/env bash

set -euo pipefail

MODEL_NAME="${MODEL_NAME:-Qwen/Qwen1.5-MoE-A2.7B-Chat}"
SERVED_MODEL_NAME="${SERVED_MODEL_NAME:-qwen-moe-ep}"
HOST="${HOST:-127.0.0.1}"
PORT="${PORT:-8000}"
GPU_MEMORY_UTILIZATION="${GPU_MEMORY_UTILIZATION:-0.88}"
MAX_MODEL_LEN="${MAX_MODEL_LEN:-4096}"

echo "Starting vLLM in EP mode"
echo "Model: ${MODEL_NAME}"
echo "Endpoint: http://${HOST}:${PORT}"
echo "GPU memory utilization: ${GPU_MEMORY_UTILIZATION}"
echo "Max model len: ${MAX_MODEL_LEN}"

if ! command -v ninja >/dev/null 2>&1; then
  echo "Error: ninja is not installed."
  echo "Fix on the VM: apt-get update && apt-get install -y ninja-build cmake pkg-config && /opt/linode-moe/.venv/bin/pip install ninja"
  exit 1
fi

CUDA_VISIBLE_DEVICES=0,1 /opt/linode-moe/.venv/bin/vllm serve "${MODEL_NAME}" \
  --host "${HOST}" \
  --port "${PORT}" \
  --served-model-name "${SERVED_MODEL_NAME}" \
  --dtype bfloat16 \
  --gpu-memory-utilization "${GPU_MEMORY_UTILIZATION}" \
  --max-model-len "${MAX_MODEL_LEN}" \
  --tensor-parallel-size 2 \
  --enable-expert-parallel \
  --trust-remote-code
