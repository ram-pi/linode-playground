#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ -f ".runtime.env" ]]; then
  set -a
  # shellcheck disable=SC1091
  source ".runtime.env"
  set +a
fi
if [[ -f ".env.local" ]]; then
  set -a
  # shellcheck disable=SC1091
  source ".env.local"
  set +a
fi

: "${KUBECONFIG:?Set KUBECONFIG or source .runtime.env}"
: "${LINODE_BUCKET:?Set LINODE_BUCKET or source .runtime.env}"
: "${LINODE_ENDPOINT:?Set LINODE_ENDPOINT or source .runtime.env}"
: "${MODEL_OBJECT_KEY:?Set MODEL_OBJECT_KEY or source .runtime.env}"

if [[ -z "${LINODE_ACCESS_KEY:-}" ]]; then
  LINODE_ACCESS_KEY="$(tofu output -raw object_storage_access_key 2>/dev/null || true)"
fi
if [[ -z "${LINODE_SECRET_KEY:-}" ]]; then
  LINODE_SECRET_KEY="$(tofu output -raw object_storage_secret_key 2>/dev/null || true)"
fi

: "${LINODE_ACCESS_KEY:?Set LINODE_ACCESS_KEY in the environment or .env.local}"
: "${LINODE_SECRET_KEY:?Set LINODE_SECRET_KEY in the environment or .env.local}"

namespace="model-cache-benchmark"
results_dir="benchmark-results/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$results_dir"

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required tool: $1"
    exit 1
  fi
}

wait_for_gpu_capacity() {
  for _ in $(seq 1 120); do
    if kubectl get nodes -l pool=gpu -o jsonpath='{.items[*].status.allocatable.nvidia\.com/gpu}' | grep -q '[1-9]'; then
      return 0
    fi
    sleep 5
  done

  echo "Timed out waiting for nvidia.com/gpu allocatable capacity on pool=gpu nodes"
  kubectl get nodes -l pool=gpu -o wide
  kubectl -n kube-system get daemonset nvidia-device-plugin -o wide || true
  return 1
}

now_s() {
  date +%s
}

wait_for_pod_name() {
  local app="$1"
  local pod=""
  for _ in $(seq 1 120); do
    pod="$(kubectl -n "$namespace" get pod -l "app=$app" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
    if [[ -n "$pod" ]]; then
      printf '%s' "$pod"
      return 0
    fi
    sleep 2
  done
  echo "Timed out waiting for pod with app=$app" >&2
  return 1
}

delete_inference_workloads() {
  kubectl -n "$namespace" delete deployment llama-s3-download llama-hostpath-cache --ignore-not-found=true
  kubectl -n "$namespace" delete service llama-s3-download llama-hostpath-cache --ignore-not-found=true

  for _ in $(seq 1 120); do
    local pods
    pods="$(kubectl -n "$namespace" get pods -l 'app in (llama-s3-download,llama-hostpath-cache)' --no-headers 2>/dev/null || true)"
    if [[ -z "$pods" ]]; then
      return 0
    fi
    sleep 2
  done

  echo "Timed out waiting for previous inference pods to terminate"
  kubectl -n "$namespace" get pods -l 'app in (llama-s3-download,llama-hostpath-cache)' -o wide || true
  return 1
}

first_request() {
  local service="$1"
  local port_file="$results_dir/${service}-port-forward.log"
  local response_file="$results_dir/${service}-response.json"

  kubectl -n "$namespace" port-forward "svc/$service" 18080:8080 >"$port_file" 2>&1 &
  local pf_pid=$!
  trap 'kill "$pf_pid" >/dev/null 2>&1 || true' RETURN

  for _ in $(seq 1 60); do
    if curl -fsS "http://127.0.0.1:18080/health" >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done

  curl -fsS \
    -o "$response_file" \
    -w '%{time_total}' \
    -H 'Content-Type: application/json' \
    -d '{"prompt":"Write one short sentence about object storage caching.","n_predict":24,"temperature":0.1}' \
    "http://127.0.0.1:18080/completion"
}

benchmark_deployment() {
  local name="$1"
  local app="$2"
  local manifest="$3"
  local service="$4"

  delete_inference_workloads

  local start
  start="$(now_s)"
  kubectl apply -f "$manifest"
  kubectl -n "$namespace" rollout status "deployment/$name" --timeout=30m
  local ready
  ready="$(now_s)"
  local pod
  pod="$(wait_for_pod_name "$app")"
  local latency
  latency="$(first_request "$service")"
  local first_ok
  first_ok="$(now_s)"

  kubectl -n "$namespace" logs "$pod" --all-containers=true >"$results_dir/${name}.log" || true
  local download_ms="n/a"
  download_ms="$(kubectl -n "$namespace" exec "$pod" -c llama-server -- sh -c 'cat /benchmark/download_ms 2>/dev/null || true' || true)"
  if [[ -z "$download_ms" ]]; then
    download_ms="n/a"
  fi

  printf '%s,%s,%s,%s,%s\n' "$name" "$download_ms" "$((ready - start))" "$((first_ok - start))" "$latency" >>"$results_dir/summary.csv"
}

require_tool kubectl
require_tool helm
require_tool envsubst
require_tool curl

kubectl get nodes -o wide

helm repo add nvdp https://nvidia.github.io/k8s-device-plugin >/dev/null
helm repo update >/dev/null
kubectl label nodes -l pool=gpu nvidia.com/gpu.present=true --overwrite
nvidia_chart_version="${NVIDIA_DEVICE_PLUGIN_CHART_VERSION:-$(helm search repo nvdp/nvidia-device-plugin --versions | awk 'NR == 2 {print $2}')}"
nvidia_chart_version="${nvidia_chart_version//[[:space:]]/}"
helm upgrade --install nvidia-device-plugin nvdp/nvidia-device-plugin \
  --namespace kube-system \
  --version "$nvidia_chart_version" \
  --wait --timeout 10m
wait_for_gpu_capacity

kubectl apply -f configs/00-namespace.yaml

kubectl -n "$namespace" create secret generic s3-credentials \
  --from-literal=AWS_ACCESS_KEY_ID="$LINODE_ACCESS_KEY" \
  --from-literal=AWS_SECRET_ACCESS_KEY="$LINODE_SECRET_KEY" \
  --from-literal=AWS_DEFAULT_REGION="us-east-1" \
  --dry-run=client -o yaml | kubectl apply -f -

envsubst < configs/10-model-config.yaml.tpl | kubectl apply -f -

printf 'case,download_ms,ready_seconds,first_request_seconds,first_request_latency_seconds\n' >"$results_dir/summary.csv"

delete_inference_workloads

benchmark_deployment "llama-s3-download" "llama-s3-download" "configs/20-download-deployment.yaml" "llama-s3-download"

kubectl apply -f configs/30-prefetch-daemonset.yaml
kubectl -n "$namespace" rollout status daemonset/model-prefetch --timeout=30m
kubectl -n "$namespace" get pods -l app=model-prefetch -o wide >"$results_dir/prefetch-pods.txt"
kubectl -n "$namespace" logs -l app=model-prefetch --all-containers=true --prefix=true >"$results_dir/prefetch.log" || true

benchmark_deployment "llama-hostpath-cache" "llama-hostpath-cache" "configs/40-hostpath-deployment.yaml" "llama-hostpath-cache"

echo ""
echo "Benchmark summary:"
column -s, -t "$results_dir/summary.csv" || cat "$results_dir/summary.csv"
echo ""
echo "Results written to $results_dir"
