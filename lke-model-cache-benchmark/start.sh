#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

if [[ -f ".env.local" ]]; then
  set -a
  # shellcheck disable=SC1091
  source ".env.local"
  set +a
fi

: "${LINODE_TOKEN:?Set LINODE_TOKEN in the environment or .env.local}"
: "${HF_TOKEN:?Set HF_TOKEN in the environment or .env.local for Hugging Face model download}"

export HF_MODEL_REPO="${HF_MODEL_REPO:-bartowski/Qwen2.5-14B-Instruct-GGUF}"
export HF_MODEL_FILE="${HF_MODEL_FILE:-Qwen2.5-14B-Instruct-Q4_K_M.gguf}"
export MODEL_OBJECT_KEY="${MODEL_OBJECT_KEY:-models/qwen2.5-14b-instruct-q4_k_m.gguf}"

tofu init
tofu apply -auto-approve

export KUBECONFIG="$PWD/kubeconfig"
export LINODE_BUCKET="$(tofu output -raw object_storage_bucket_name)"
export LINODE_ENDPOINT="$(tofu output -raw object_storage_endpoint)"
export LINODE_ACCESS_KEY="$(tofu output -raw object_storage_access_key)"
export LINODE_SECRET_KEY="$(tofu output -raw object_storage_secret_key)"
export JUICEFS_BUCKET="$(tofu output -raw juicefs_object_storage_bucket_name)"
export JUICEFS_ENDPOINT="$(tofu output -raw juicefs_object_storage_endpoint)"
export JUICEFS_BUCKET_URL="$(tofu output -raw juicefs_object_storage_bucket_url)"

uv run scripts/upload_model.py

cat > .runtime.env <<EOF
export KUBECONFIG="$PWD/kubeconfig"
export LINODE_BUCKET="$LINODE_BUCKET"
export LINODE_ENDPOINT="$LINODE_ENDPOINT"
export JUICEFS_BUCKET="$JUICEFS_BUCKET"
export JUICEFS_ENDPOINT="$JUICEFS_ENDPOINT"
export JUICEFS_BUCKET_URL="$JUICEFS_BUCKET_URL"
export MODEL_OBJECT_KEY="$MODEL_OBJECT_KEY"
export HF_MODEL_REPO="$HF_MODEL_REPO"
export HF_MODEL_FILE="$HF_MODEL_FILE"
EOF

echo "Infrastructure ready. Run: source .runtime.env && bash scripts/run-benchmark.sh"
echo "For the JuiceFS RWX benchmark, run: source .runtime.env && bash scripts/run-juicefs-benchmark.sh"
