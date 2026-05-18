# Manual Deployment Runbook

This document covers Phase 2: validating the dual-GPU runtime and benchmarking vLLM throughput for MoE with DP and EP modes on the VM created by `./start.sh`.

## Prerequisites

| Tool | Install |
|------|---------|
| `tofu` | OpenTofu 1.8+ |
| `jq` | `brew install jq` or `apt-get install jq` |
| `ssh` | Preinstalled on macOS/Linux |

## Step 1 - Get connection details

Run from `linode_MoE/` on your local machine:

```bash
tofu output -raw ssh_command
tofu output -raw public_ip
```

SSH into the VM:

```bash
ssh -i "$(tofu output -raw ssh_private_key_path)" root@"$(tofu output -raw public_ip)"
```

## Step 2 - Verify cloud-init and GPU readiness

On the VM:

```bash
cloud-init status --wait
linode-moe-healthcheck
command -v ninja && ninja --version
nvidia-smi
```

Expected:

- `cloud-init` reports `status: done`
- Two GPUs visible in `nvidia-smi`
- `ninja` is installed and returns a version
- vLLM version prints successfully

## Step 3 - Stage benchmark scripts on VM

Run from local machine (inside `linode_MoE/`):

```bash
VM_IP="$(tofu output -raw public_ip)"
VM_KEY="$(tofu output -raw ssh_private_key_path)"

scp -i "$VM_KEY" scripts/*.sh scripts/*.py root@"$VM_IP":/opt/linode-moe/
ssh -i "$VM_KEY" root@"$VM_IP" 'chmod +x /opt/linode-moe/*.sh'
```

Check installed vLLM capabilities:

```bash
ssh -i "$VM_KEY" root@"$VM_IP" '/opt/linode-moe/check_vllm_capabilities.sh'
```

If you previously started vLLM and stopped it with an error, clean up any lingering worker processes before retrying:

```bash
ssh -i "$VM_KEY" root@"$VM_IP" '/opt/linode-moe/cleanup_vllm_processes.sh'
```

## Step 4 - Start vLLM in TP (Tensor Parallel) mode

> **Why TP and not DP?**
> `Qwen1.5-MoE-A2.7B-Chat` has ~14.3B *total* parameters (the "2.7B" refers to
> *active* parameters per forward pass via MoE routing). In bf16 the weights
> consume ~28 GB — more than one RTX 4000 Ada (20 GB). Pure DP requires a full
> model copy on each GPU, so it cannot work here. TP splits each weight tensor
> across both GPUs, giving ~14 GB per GPU and leaving headroom for KV cache.
> TP is the correct 2-GPU baseline to compare against EP.

On the VM:

```bash
cd /opt/linode-moe
MODEL_NAME="Qwen/Qwen1.5-MoE-A2.7B-Chat" \
./start_vllm_dp.sh | tee tp-server.log
```

In a second VM shell, smoke test:

```bash
curl -s http://127.0.0.1:8000/v1/models | jq
```

## Step 5 - Run TP load test (tokens/sec vs concurrency)

On the VM:

```bash
cd /opt/linode-moe
MODEL_NAME="qwen-moe-tp" \
REQUESTS_PER_LEVEL=80 \
CONCURRENCY_LEVELS="1 2 4 8 16 32" \
./run_benchmark_sweep.sh
```

Expected output:

- JSON files under `/opt/linode-moe/results`
- One CSV summary with columns:
  - `concurrency`
  - `success_rate`
  - `tokens_per_second`
  - `p50_latency_s`
  - `p95_latency_s`

## Step 6 - Stop TP and start EP mode

Stop TP server in its shell (`Ctrl+C`). Then on VM:

```bash
cd /opt/linode-moe
./cleanup_vllm_processes.sh
MODEL_NAME="Qwen/Qwen1.5-MoE-A2.7B-Chat" \
./start_vllm_ep.sh | tee ep-server.log
```

In a second VM shell, smoke test:

```bash
curl -s http://127.0.0.1:8000/v1/models | jq
```

## Step 7 - Run EP load test

On the VM:

```bash
cd /opt/linode-moe
MODEL_NAME="qwen-moe-ep" \
REQUESTS_PER_LEVEL=80 \
CONCURRENCY_LEVELS="1 2 4 8 16 32" \
./run_benchmark_sweep.sh
```

Compare TP vs EP CSV summaries for throughput and latency trends.

## Step 8 - MoE routing validation signals

On the VM while EP is running:

```bash
cd /opt/linode-moe
./check_moe_signals.sh
```

Signals to examine:

- Expert load balance across experts
- Routing entropy / top-k spread
- Token drop or overflow indicators
- Per-expert latency skew and queue buildup

Healthy pattern:

- No persistent collapse to a tiny subset of experts
- Low overflow/drop rate
- Throughput increases with concurrency up to saturation point

## Step 9 - Copy results to local machine (optional)

From local machine:

```bash
VM_IP="$(tofu output -raw public_ip)"
VM_KEY="$(tofu output -raw ssh_private_key_path)"
mkdir -p results
scp -i "$VM_KEY" root@"$VM_IP":/opt/linode-moe/results/* ./results/
```

## Troubleshooting

Cloud-init still running:

```bash
tail -f /var/log/cloud-init-output.log
```

Driver install issues:

```bash
apt-cache policy nvidia-open cuda-toolkit-12-8
nvidia-smi
```

Missing `ninja` during vLLM startup:

```bash
apt-get update
apt-get install -y ninja-build cmake pkg-config
/opt/linode-moe/.venv/bin/pip install ninja
command -v ninja
ninja --version
```

Then retry:

```bash
cd /opt/linode-moe
./cleanup_vllm_processes.sh
MODEL_NAME="Qwen/Qwen1.5-MoE-A2.7B-Chat" \
./start_vllm_dp.sh | tee tp-server.log
```

vLLM fails with "No available memory for cache blocks":

- This error means the model weights consumed all GPU memory leaving nothing for KV cache.
- Do NOT use `--data-parallel-size 2` with this model: `Qwen1.5-MoE-A2.7B-Chat` has ~14.3B total parameters (~28 GB in bf16), which does not fit on a single 20 GB GPU. Pure DP requires a full model copy per GPU.
- The launcher (`start_vllm_dp.sh`) already uses `--tensor-parallel-size 2` (TP mode) which splits weights across both GPUs. If the error persists, run `./cleanup_vllm_processes.sh` to free VRAM from stale processes and retry.
- Lower `GPU_MEMORY_UTILIZATION` only if stale processes are not the cause.

Benchmark errors/timeouts:

```bash
cat /opt/linode-moe/results/*.json | jq '.failed, .sample_errors'
```
