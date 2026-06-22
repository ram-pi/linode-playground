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
enable_rclone_case="${ENABLE_RCLONE_CASE:-false}"

cleanup_on_exit() {
  delete_inference_workloads || true
}

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

seconds_to_ms() {
  awk -v seconds="$1" 'BEGIN { printf "%.0f", seconds * 1000 }'
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

metric_or_na() {
  if [[ -n "$1" ]]; then
    printf '%s' "$1"
  else
    printf 'n/a'
  fi
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
  local selector='app in (llama-s3-download,llama-hostpath-cache,llama-rclone-sidecar)'

  kubectl -n "$namespace" delete deployment llama-s3-download llama-hostpath-cache llama-rclone-sidecar \
    --ignore-not-found=true --wait=false
  kubectl -n "$namespace" delete service llama-s3-download llama-hostpath-cache llama-rclone-sidecar \
    --ignore-not-found=true
  kubectl -n "$namespace" delete pod -l "$selector" \
    --force --grace-period=0 --ignore-not-found=true >/dev/null 2>&1 || true

  for _ in $(seq 1 120); do
    local pods
    pods="$(kubectl -n "$namespace" get pods -l "$selector" --no-headers 2>/dev/null || true)"
    if [[ -z "$pods" ]]; then
      return 0
    fi
    sleep 2
  done

  echo "Timed out waiting for previous inference pods to terminate; forcing pod deletion"
  kubectl -n "$namespace" delete pod -l "$selector" --force --grace-period=0 --ignore-not-found=true >/dev/null 2>&1 || true

  for _ in $(seq 1 30); do
    local pods
    pods="$(kubectl -n "$namespace" get pods -l "$selector" --no-headers 2>/dev/null || true)"
    if [[ -z "$pods" ]]; then
      return 0
    fi
    sleep 2
  done

  echo "Timed out waiting for previous inference pods to terminate after force deletion"
  kubectl -n "$namespace" get pods -l "$selector" -o wide || true
  return 1
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
    -d '{"prompt":"Write one short sentence about object storage caching.","n_predict":24,"temperature":0.1}' \
    "http://127.0.0.1:18080/completion"
}

benchmark_deployment() {
  local name="$1"
  local app="$2"
  local manifest="$3"
  local service="$4"
  local model_delivery="$5"
  local download_phase_ms="$6"
  local notes="$7"

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

  local log_file="$results_dir/${name}.log"
  kubectl -n "$namespace" logs "$pod" --all-containers=true >"$log_file" || true

  if [[ "$download_phase_ms" == "from-pod" ]]; then
    download_phase_ms="$(kubectl -n "$namespace" exec "$pod" -c llama-server -- sh -c 'cat /benchmark/download_ms 2>/dev/null || true' || true)"
    download_phase_ms="$(metric_or_na "$download_phase_ms")"
  fi

  local first_request_client_ms
  first_request_client_ms="$(seconds_to_ms "$latency")"
  local server_startup_ms
  server_startup_ms="$(llama_log_elapsed_ms "$log_file" 'llama_server: model loaded')"
  local model_load_ms
  model_load_ms="$(llama_log_delta_ms "$log_file" 'llama_server: loading model' 'llama_server: model loaded')"
  if [[ "$download_phase_ms" == "from-model-load" ]]; then
    download_phase_ms="$model_load_ms"
  fi
  local first_request_prompt_eval_ms
  first_request_prompt_eval_ms="$(metric_or_na "$(llama_timing_ms "$log_file" prompt)")"
  local first_request_generation_ms
  first_request_generation_ms="$(metric_or_na "$(llama_timing_ms "$log_file" generation)")"
  local first_request_model_ms
  first_request_model_ms="$(metric_or_na "$(llama_timing_ms "$log_file" total)")"

  printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' \
    "$name" \
    "$model_delivery" \
    "$download_phase_ms" \
    "$cache_warmup_ms" \
    "$server_startup_ms" \
    "$model_load_ms" \
    "$((ready - start))" \
    "$((first_ok - start))" \
    "$first_request_client_ms" \
    "$first_request_prompt_eval_ms" \
    "$first_request_generation_ms" \
    "$first_request_model_ms" \
    "$notes" >>"$results_dir/summary.csv"
}

collect_cache_warmup_ms() {
  local pod
  pod="$(wait_for_pod_name model-prefetch)"
  local value
  value="$(kubectl -n "$namespace" exec "$pod" -c prefetch -- sh -c 'cat /host-cache/download_ms 2>/dev/null || true' || true)"
  metric_or_na "$value"
}

generate_markdown_summary() {
  local summary_md="$results_dir/summary.md"

  {
    printf '# Benchmark Summary\n\n'
    printf 'Results generated at `%s`.\n\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')"
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
    done <"$results_dir/summary.csv"

    printf '\n## Interpretation\n\n'
    printf 'HostPath cache-hit download phase is expected to be `0 ms`; cache population is shown separately as cache warmup. rclone has no explicit download phase because object-storage reads happen lazily through FUSE during model load.\n\n'
    printf '## Download Phase\n\n'
    render_mermaid_chart "Explicit Download Phase" "download_phase_ms"
    printf '\n## Server Startup And First Request\n\n'
    render_mermaid_chart "Model Load" "model_load_ms"
    printf '\n'
    render_mermaid_chart "First Request Model Time" "first_request_model_ms"
  } >"$summary_md"
}

metric_column_index() {
  case "$1" in
    download_phase_ms) printf '3' ;;
    model_load_ms) printf '6' ;;
    first_request_model_ms) printf '12' ;;
    *) printf '0' ;;
  esac
}

render_mermaid_chart() {
  local title="$1"
  local first_metric="$2"

  printf '```mermaid\n'
  printf 'xychart-beta\n'
  printf '  title "%s"\n' "$title"
  printf '  x-axis ['
  local first=true
  while IFS=, read -r case _model_delivery _download_phase _cache_warmup _server_startup _model_load _ready _first_response _client_latency _prompt _generation _model_latency _notes; do
    if [[ "$case" == "case" ]]; then
      continue
    fi
    if [[ "$first" == "true" ]]; then first=false; else printf ', '; fi
    printf '"%s"' "$case"
  done <"$results_dir/summary.csv"
  printf ']\n'
  printf '  y-axis "milliseconds" 0 --> 10000\n'
  render_mermaid_bar "$first_metric"
  printf '```\n'
}

render_mermaid_bar() {
  local metric="$1"
  local index
  index="$(metric_column_index "$metric")"

  printf '  bar ['

  local first=true
  while IFS=, read -r case model_delivery download_phase cache_warmup server_startup model_load ready first_response client_latency prompt generation model_latency notes; do
    if [[ "$case" == "case" ]]; then
      continue
    fi
    if [[ "$first" == "true" ]]; then first=false; else printf ', '; fi
    local value="0"
    case "$index" in
      3) value="$download_phase" ;;
      6) value="$model_load" ;;
      12) value="$model_latency" ;;
    esac
    if [[ "$value" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
      printf '%s' "$value"
    else
      printf '0'
    fi
  done <"$results_dir/summary.csv"
  printf ']\n'
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

printf 'case,model_delivery,download_phase_ms,cache_warmup_ms,server_startup_ms,model_load_ms,ready_seconds,first_response_seconds,first_request_client_ms,first_request_prompt_eval_ms,first_request_generation_ms,first_request_model_ms,notes\n' >"$results_dir/summary.csv"

delete_inference_workloads

cache_warmup_ms="n/a"
benchmark_deployment "llama-s3-download" "llama-s3-download" "configs/20-download-deployment.yaml" "llama-s3-download" \
  "pod init-container download" "from-pod" "downloads model before llama.cpp starts"

kubectl apply -f configs/30-prefetch-daemonset.yaml
kubectl -n "$namespace" rollout status daemonset/model-prefetch --timeout=30m
kubectl -n "$namespace" get pods -l app=model-prefetch -o wide >"$results_dir/prefetch-pods.txt"
kubectl -n "$namespace" logs -l app=model-prefetch --all-containers=true --prefix=true >"$results_dir/prefetch.log" || true
cache_warmup_ms="$(collect_cache_warmup_ms)"

benchmark_deployment "llama-hostpath-cache" "llama-hostpath-cache" "configs/40-hostpath-deployment.yaml" "llama-hostpath-cache" \
  "node-local hostPath cache" "0" "cache hit so no pod-level download"

if [[ "$enable_rclone_case" == "true" ]]; then
  cache_warmup_ms="n/a"
  benchmark_deployment "llama-rclone-sidecar" "llama-rclone-sidecar" "configs/50-rclone-sidecar-deployment.yaml" "llama-rclone-sidecar" \
    "rclone FUSE lazy read" "from-model-load" "download phase is lazy remote read during model load"
fi

generate_markdown_summary

echo ""
echo "Benchmark summary:"
column -s, -t "$results_dir/summary.csv" || cat "$results_dir/summary.csv"
echo ""
echo "Markdown summary written to $results_dir/summary.md"
echo "Results written to $results_dir"
