#!/usr/bin/env bash

set -euo pipefail

echo "=== Before cleanup ==="
nvidia-smi || true
echo

echo "Stopping known vLLM-related processes..."
pkill -f "vllm serve" || true
pkill -f multiproc_executor || true
pkill -f EngineCore || true
pkill -f ApiServer || true
pkill -f WorkerProc || true
sleep 3

echo
echo "=== After cleanup ==="
nvidia-smi || true
