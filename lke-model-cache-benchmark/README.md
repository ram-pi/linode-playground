# LKE Model Cache Benchmark

Benchmark model-serving cold start on LKE GPU nodes when a GGUF model is loaded from:

- a direct Linode Object Storage download during pod startup
- a node-local hostPath cache populated by a DaemonSet

Default region is `de-fra-2` for LKE and Object Storage. Akamai documents the Object Storage S3 hostname for `de-fra-2` as `de-fra-1.linodeobjects.com`; this demo uses the bucket's computed `s3_endpoint` output instead of deriving the endpoint hostname from the region string. The default model is `bartowski/Qwen2.5-14B-Instruct-GGUF` with `Qwen2.5-14B-Instruct-Q4_K_M.gguf`, which remains suitable for testing on a single `g2-gpu-rtx4000a1-m` node with 24 GB VRAM.

## Architecture

![alt text](architecture.excalidraw.svg)

## Quick Start

```bash
export LINODE_TOKEN="..."
export HF_TOKEN="..."

cd lke-model-cache-benchmark
bash start.sh
source .runtime.env
bash scripts/run-benchmark.sh
```

The benchmark writes logs and `summary.csv` under `benchmark-results/`.

## What Is Measured

`llama-s3-download` measures pod startup with an init container that downloads the model from Object Storage into `emptyDir`, then starts `llama.cpp` and serves one request.

`model-prefetch` measures node-local cache warmup by downloading the same object to `/var/lib/model-cache-benchmark/model.gguf` on each worker.

`llama-hostpath-cache` measures startup when the GPU pod mounts the warmed host cache and starts `llama.cpp` without downloading the model again.

## KServe And KubeRay Cache Note

KServe `LocalModelCache` is the managed/operator version of this node-level cache pattern: it provides `LocalModelCache`, `LocalModelNodeGroup`, and `LocalModelNode` resources, creates download jobs, tracks per-node cache status, and integrates with `InferenceService` by matching the model `storageUri`.

KubeRay does not provide an equivalent native node-level model artifact cache. Ray `runtime_env` has caching for Python dependencies, code packages, and working directories, but it is not a lifecycle manager for large model weights. For KubeRay/Ray Serve, use Kubernetes primitives such as a prefetch DaemonSet, hostPath/local PV mounts, PVCs, or init containers.

This demo intentionally uses the generic Kubernetes DaemonSet plus hostPath approach so the pattern can be reused with KubeRay, Ray Serve, `llama.cpp`, vLLM, or other inference engines.

The summary columns are:

- `download_ms`: model download time for the direct-download init container, or `n/a` for hostPath startup
- `ready_seconds`: deployment apply to Kubernetes rollout-ready
- `first_request_seconds`: deployment apply to first successful inference response
- `first_request_latency_seconds`: latency of the first `/completion` call after readiness

## Troubleshooting

If rollout is stuck at `0 of 1 updated replicas are available`, check whether another inference deployment is still using the single GPU:

```bash
kubectl -n model-cache-benchmark get pods -o wide
kubectl -n model-cache-benchmark describe pod -l app=llama-s3-download
```

This demo uses one GPU node, so `llama-s3-download` and `llama-hostpath-cache` cannot run at the same time. `scripts/run-benchmark.sh` deletes both inference deployments before each benchmark case to avoid `Insufficient nvidia.com/gpu` scheduling failures.

## Configuration

Override defaults before running `start.sh`:

```bash
export HF_MODEL_REPO="bartowski/Qwen2.5-14B-Instruct-GGUF"
export HF_MODEL_FILE="Qwen2.5-14B-Instruct-Q4_K_M.gguf"
export MODEL_OBJECT_KEY="models/qwen2.5-14b-instruct-q4_k_m.gguf"
```

GPU and cluster sizing are controlled in `variables.tf` or `terraform.tfvars`.

## Cleanup

```bash
bash shutdown.sh
```

This deletes the Kubernetes namespace, empties the Object Storage bucket, and destroys the LKE cluster and bucket.
