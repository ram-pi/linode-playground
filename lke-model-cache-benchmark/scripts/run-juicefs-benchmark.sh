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
if [[ -z "${JUICEFS_BUCKET:-}" ]]; then
  JUICEFS_BUCKET="$(tofu output -raw juicefs_object_storage_bucket_name 2>/dev/null || true)"
fi
if [[ -z "${JUICEFS_ENDPOINT:-}" ]]; then
  JUICEFS_ENDPOINT="$(tofu output -raw juicefs_object_storage_endpoint 2>/dev/null || true)"
fi
if [[ -z "${JUICEFS_BUCKET_URL:-}" ]]; then
  JUICEFS_BUCKET_URL="$(tofu output -raw juicefs_object_storage_bucket_url 2>/dev/null || true)"
fi
if [[ -z "${JUICEFS_BUCKET_URL:-}" && -n "${JUICEFS_ENDPOINT:-}" && -n "${JUICEFS_BUCKET:-}" ]]; then
  JUICEFS_BUCKET_URL="${JUICEFS_ENDPOINT%/}/${JUICEFS_BUCKET}"
fi
if [[ -z "${JUICEFS_ACCESS_KEY:-}" ]]; then
  JUICEFS_ACCESS_KEY="$(tofu output -raw juicefs_object_storage_access_key 2>/dev/null || true)"
fi
if [[ -z "${JUICEFS_SECRET_KEY:-}" ]]; then
  JUICEFS_SECRET_KEY="$(tofu output -raw juicefs_object_storage_secret_key 2>/dev/null || true)"
fi

: "${LINODE_ACCESS_KEY:?Set LINODE_ACCESS_KEY in the environment or .env.local}"
: "${LINODE_SECRET_KEY:?Set LINODE_SECRET_KEY in the environment or .env.local}"
: "${JUICEFS_BUCKET:?Set JUICEFS_BUCKET in the environment, .runtime.env, or Terraform outputs}"
: "${JUICEFS_ENDPOINT:?Set JUICEFS_ENDPOINT in the environment, .runtime.env, or Terraform outputs}"
: "${JUICEFS_BUCKET_URL:?Set JUICEFS_BUCKET_URL in the environment, .runtime.env, or Terraform outputs}"
: "${JUICEFS_ACCESS_KEY:?Set JUICEFS_ACCESS_KEY in the environment or Terraform outputs}"
: "${JUICEFS_SECRET_KEY:?Set JUICEFS_SECRET_KEY in the environment or Terraform outputs}"

namespace="model-cache-benchmark"
results_dir="benchmark-results/$(date +%Y%m%d-%H%M%S)-juicefs"
mkdir -p "$results_dir"
juicefs_csi_chart_version="${JUICEFS_CSI_CHART_VERSION:-0.31.10}"

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Missing required tool: $1"
    exit 1
  fi
}

now_s() {
  date +%s
}

seconds_to_ms() {
  awk -v seconds="$1" 'BEGIN { printf "%.0f", seconds * 1000 }'
}

metric_or_na() {
  if [[ -n "$1" ]]; then
    printf '%s' "$1"
  else
    printf 'n/a'
  fi
}

llama_log_timestamp_ms() {
  local log_file="$1"
  local pattern="$2"

  awk -v pattern="$pattern" '
    $0 ~ pattern {
      split($1, parts, ".")
      if (parts[4] != "") {
        printf "%.0f", ((parts[1] * 60 + parts[2]) * 1000 + parts[3] + parts[4] / 1000)
        exit
      }
    }
  ' "$log_file"
}

llama_log_delta_ms() {
  local log_file="$1"
  local start_pattern="$2"
  local end_pattern="$3"
  local start_ms
  local end_ms

  start_ms="$(llama_log_timestamp_ms "$log_file" "$start_pattern")"
  end_ms="$(llama_log_timestamp_ms "$log_file" "$end_pattern")"
  if [[ -z "$start_ms" || -z "$end_ms" ]]; then
    printf 'n/a'
    return 0
  fi

  printf '%s' "$((end_ms - start_ms))"
}

llama_log_elapsed_ms() {
  local log_file="$1"
  local pattern="$2"
  local value

  value="$(llama_log_timestamp_ms "$log_file" "$pattern")"
  if [[ -z "$value" ]]; then
    printf 'n/a'
    return 0
  fi

  printf '%s' "$value"
}

llama_timing_ms() {
  local log_file="$1"
  local timing="$2"

  awk -v timing="$timing" '
    timing == "prompt" && /prompt eval time =/ {
      sub(/^.*prompt eval time = */, "")
      split($0, parts, " ")
      print parts[1]
      exit
    }
    timing == "generation" && / eval time =/ && $0 !~ /prompt eval time =/ {
      sub(/^.*eval time = */, "")
      split($0, parts, " ")
      print parts[1]
      exit
    }
    timing == "total" && /total time =/ {
      sub(/^.*total time = */, "")
      split($0, parts, " ")
      print parts[1]
      exit
    }
  ' "$log_file"
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

delete_juicefs_benchmark_workloads() {
  kubectl -n "$namespace" delete deployment llama-juicefs-rwx --ignore-not-found=true --wait=false
  kubectl -n "$namespace" delete service llama-juicefs-rwx --ignore-not-found=true
  kubectl -n "$namespace" delete job juicefs-prefetch juicefs-rwx-write juicefs-rwx-read juicefs-cache-check --ignore-not-found=true --wait=false
  kubectl -n "$namespace" delete pod -l 'app in (llama-juicefs-rwx,juicefs-prefetch,juicefs-rwx-write,juicefs-rwx-read,juicefs-cache-check)' \
    --force --grace-period=0 --ignore-not-found=true >/dev/null 2>&1 || true
}

cleanup_on_exit() {
  delete_juicefs_benchmark_workloads || true
}

trap cleanup_on_exit EXIT

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
    -d '{"prompt":"Write one short sentence about shared model storage.","n_predict":24,"temperature":0.1}' \
    "http://127.0.0.1:18080/completion"
}

install_platform_dependencies() {
  helm repo add nvdp https://nvidia.github.io/k8s-device-plugin >/dev/null
  helm repo add juicefs https://juicedata.github.io/charts/ >/dev/null
  helm repo update >/dev/null

  kubectl label nodes -l pool=gpu nvidia.com/gpu.present=true --overwrite
  local nvidia_chart_version
  nvidia_chart_version="${NVIDIA_DEVICE_PLUGIN_CHART_VERSION:-$(helm search repo nvdp/nvidia-device-plugin --versions | awk 'NR == 2 {print $2}')}"
  nvidia_chart_version="${nvidia_chart_version//[[:space:]]/}"
  helm upgrade --install nvidia-device-plugin nvdp/nvidia-device-plugin \
    --namespace kube-system \
    --version "$nvidia_chart_version" \
    --wait --timeout 10m
  wait_for_gpu_capacity

  helm upgrade --install juicefs-csi-driver juicefs/juicefs-csi-driver \
    --namespace kube-system \
    --version "$juicefs_csi_chart_version" \
    --wait --timeout 10m
}

apply_base_resources() {
  kubectl apply -f configs/00-namespace.yaml

  kubectl -n "$namespace" create secret generic s3-credentials \
    --from-literal=AWS_ACCESS_KEY_ID="$LINODE_ACCESS_KEY" \
    --from-literal=AWS_SECRET_ACCESS_KEY="$LINODE_SECRET_KEY" \
    --from-literal=AWS_DEFAULT_REGION="us-east-1" \
    --dry-run=client -o yaml | kubectl apply -f -

  envsubst < configs/10-model-config.yaml.tpl | kubectl apply -f -
}

apply_juicefs_resources() {
  kubectl apply -f configs/60-juicefs-redis.yaml
  kubectl -n "$namespace" rollout status deployment/juicefs-redis --timeout=10m
  envsubst < configs/61-juicefs-secret.yaml.tpl | kubectl apply -f -
  kubectl apply -f configs/62-juicefs-storageclass.yaml
  kubectl apply -f configs/63-juicefs-pvc.yaml
}

verify_rwx() {
  kubectl -n "$namespace" delete job juicefs-rwx-write juicefs-rwx-read --ignore-not-found=true --wait=false
  kubectl -n "$namespace" delete pod -l 'app in (juicefs-rwx-write,juicefs-rwx-read)' \
    --force --grace-period=0 --ignore-not-found=true >/dev/null 2>&1 || true
  kubectl apply -f configs/66-juicefs-rwx-verify.yaml
  kubectl -n "$namespace" wait --for=condition=complete job/juicefs-rwx-write --timeout=10m
  kubectl -n "$namespace" wait --for=condition=complete job/juicefs-rwx-read --timeout=10m
  kubectl -n "$namespace" logs job/juicefs-rwx-write >"$results_dir/juicefs-rwx-write.log" || true
  kubectl -n "$namespace" logs job/juicefs-rwx-read >"$results_dir/juicefs-rwx-read.log" || true
}

check_juicefs_model_cache() {
  kubectl -n "$namespace" delete job juicefs-cache-check --ignore-not-found=true --wait=false >/dev/null
  kubectl -n "$namespace" delete pod -l app=juicefs-cache-check --force --grace-period=0 --ignore-not-found=true >/dev/null 2>&1 || true
  kubectl apply -f configs/67-juicefs-cache-check.yaml >/dev/null
  kubectl -n "$namespace" wait --for=condition=complete job/juicefs-cache-check --timeout=10m >/dev/null
  kubectl -n "$namespace" logs job/juicefs-cache-check 2>/dev/null | awk -F= '/^cache_hit=/ { value=$2 } END { print value }'
}

prefetch_model() {
  kubectl -n "$namespace" delete job juicefs-prefetch --ignore-not-found=true --wait=false >/dev/null
  kubectl -n "$namespace" delete pod -l app=juicefs-prefetch --force --grace-period=0 --ignore-not-found=true >/dev/null 2>&1 || true
  kubectl apply -f configs/64-juicefs-prefetch-job.yaml >/dev/null
  kubectl -n "$namespace" wait --for=condition=complete job/juicefs-prefetch --timeout=60m >/dev/null
  kubectl -n "$namespace" logs job/juicefs-prefetch >"$results_dir/juicefs-prefetch.log" || true

  local value
  value="$(awk -F= '/^download_ms=/ { value=$2 } END { print value }' "$results_dir/juicefs-prefetch.log")"
  metric_or_na "$value"
}

init_summary() {
  printf 'case,model_delivery,download_phase_ms,cache_warmup_ms,server_startup_ms,model_load_ms,ready_seconds,first_response_seconds,first_request_client_ms,first_request_prompt_eval_ms,first_request_generation_ms,first_request_model_ms,notes\n' >"$results_dir/juicefs-summary.csv"
}

benchmark_juicefs_deployment() {
  local case_name="$1"
  local cache_warmup_ms="$2"
  local notes="$3"
  local app="llama-juicefs-rwx"
  local start
  start="$(now_s)"
  kubectl apply -f configs/65-juicefs-rwx-deployment.yaml
  kubectl -n "$namespace" rollout status deployment/llama-juicefs-rwx --timeout=30m
  local ready
  ready="$(now_s)"
  local pod
  pod="$(wait_for_pod_name "$app")"
  local latency
  latency="$(first_request llama-juicefs-rwx)"
  local first_ok
  first_ok="$(now_s)"

  local log_file="$results_dir/${case_name}.log"
  kubectl -n "$namespace" logs "$pod" --all-containers=true >"$log_file" || true

  local first_request_client_ms
  first_request_client_ms="$(seconds_to_ms "$latency")"
  local server_startup_ms
  server_startup_ms="$(llama_log_elapsed_ms "$log_file" 'llama_server: model loaded')"
  local model_load_ms
  model_load_ms="$(llama_log_delta_ms "$log_file" 'llama_server: loading model' 'llama_server: model loaded')"
  local first_request_prompt_eval_ms
  first_request_prompt_eval_ms="$(metric_or_na "$(llama_timing_ms "$log_file" prompt)")"
  local first_request_generation_ms
  first_request_generation_ms="$(metric_or_na "$(llama_timing_ms "$log_file" generation)")"
  local first_request_model_ms
  first_request_model_ms="$(metric_or_na "$(llama_timing_ms "$log_file" total)")"

  printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
    "$case_name" \
    "JuiceFS CSI RWX PVC" \
    "0" \
    "$cache_warmup_ms" \
    "$server_startup_ms" \
    "$model_load_ms" \
    "$((ready - start))" \
    "$((first_ok - start))" \
    "$first_request_client_ms" \
    "$first_request_prompt_eval_ms" \
    "$first_request_generation_ms" \
    "$first_request_model_ms" \
    "$notes" >>"$results_dir/juicefs-summary.csv"
}

generate_markdown_summary() {
  local summary_md="$results_dir/juicefs-summary.md"

  {
    printf '# JuiceFS Benchmark Summary\n\n'
    printf 'Results generated at `%s`.\n\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')"
    printf '## Backend\n\n'
    printf '| Component | Backend |\n'
    printf '|---|---|\n'
    printf '| Raw model source | `%s` |\n' "s3://$LINODE_BUCKET/$MODEL_OBJECT_KEY"
    printf '| JuiceFS object backend | `%s` |\n' "s3://$JUICEFS_BUCKET"
    printf '| JuiceFS metadata backend | `redis://juicefs-redis.model-cache-benchmark.svc.cluster.local:6379/1` |\n\n'
    printf 'Initial PVC model cache hit: `%s`.\n\n' "$initial_pvc_cache_hit"
    printf '## Phase Metrics\n\n'
    printf '| Case | Model Delivery | Download Phase | Cache Warmup | Server Startup | Model Load | Ready | First Response | Client Latency | Model Latency | Notes |\n'
    printf '|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---|\n'

    while IFS=, read -r case model_delivery download_phase cache_warmup server_startup model_load ready first_response client_latency _prompt _generation model_latency notes; do
      if [[ "$case" == "case" ]]; then
        continue
      fi
      printf '| `%s` | %s | %s ms | %s ms | %s ms | %s ms | %s s | %s s | %s ms | %s ms | %s |\n' \
        "$case" "$model_delivery" "$download_phase" "$cache_warmup" "$server_startup" "$model_load" \
        "$ready" "$first_response" "$client_latency" "$model_latency" "$notes"
    done <"$results_dir/juicefs-summary.csv"

    printf '\n## Interpretation\n\n'
    printf 'JuiceFS uses a shared RWX PVC. The first row includes the one-time model copy into the PVC as `cache_warmup_ms`. The second row recreates the inference pod against the same PVC and verifies the model is already present, so `cache_warmup_ms` is `0`. In both inference pods, `download_phase_ms` is `0` because the pod itself does not download the model.\n'
  } >"$summary_md"
}

require_tool kubectl
require_tool helm
require_tool envsubst
require_tool curl
require_tool tofu

kubectl get nodes -o wide
install_platform_dependencies
apply_base_resources
apply_juicefs_resources
verify_rwx
initial_pvc_cache_hit="$(check_juicefs_model_cache)"
init_summary
initial_cache_warmup_ms="$(prefetch_model)"
delete_juicefs_benchmark_workloads
benchmark_juicefs_deployment \
  "llama-juicefs-rwx-initial-pod" \
  "$initial_cache_warmup_ms" \
  "first inference pod after model copy into shared RWX PVC"
delete_juicefs_benchmark_workloads
reuse_cache_warmup_ms="$(prefetch_model)"
benchmark_juicefs_deployment \
  "llama-juicefs-rwx-reuse-pod" \
  "$reuse_cache_warmup_ms" \
  "second inference pod mounts same PVC; model already present"
generate_markdown_summary

echo ""
echo "JuiceFS benchmark summary:"
column -s, -t "$results_dir/juicefs-summary.csv" || cat "$results_dir/juicefs-summary.csv"
echo ""
echo "Markdown summary written to $results_dir/juicefs-summary.md"
echo "Results written to $results_dir"
