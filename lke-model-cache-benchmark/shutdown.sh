#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

read -r -p "Delete LKE cluster, GPU node, Object Storage bucket, and benchmark workloads? Type yes: " reply
if [[ "$reply" != "yes" ]]; then
  echo "Aborted."
  exit 1
fi

if [[ -f ".env.local" ]]; then
  set -a
  # shellcheck disable=SC1091
  source ".env.local"
  set +a
fi

if [[ -f "kubeconfig" ]]; then
  export KUBECONFIG="$PWD/kubeconfig"
  kubectl delete namespace model-cache-benchmark --ignore-not-found=true || true
fi

export LINODE_BUCKET="$(tofu output -raw object_storage_bucket_name 2>/dev/null || true)"
export LINODE_ENDPOINT="$(tofu output -raw object_storage_endpoint 2>/dev/null || true)"
export LINODE_ACCESS_KEY="$(tofu output -raw object_storage_access_key 2>/dev/null || true)"
export LINODE_SECRET_KEY="$(tofu output -raw object_storage_secret_key 2>/dev/null || true)"

if [[ -n "$LINODE_BUCKET" && -n "$LINODE_ENDPOINT" && -n "$LINODE_ACCESS_KEY" && -n "$LINODE_SECRET_KEY" ]]; then
  uv run scripts/empty_bucket.py
else
  echo "Skipping bucket empty step because Object Storage outputs are unavailable."
fi

tofu destroy -auto-approve
