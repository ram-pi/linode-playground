# Manual Deployment

Use this if you want to run the phases separately instead of relying on `start.sh` and `scripts/run-benchmark.sh`.

## 1. Provision Infrastructure

```bash
export LINODE_TOKEN="..."
tofu init
tofu apply
export KUBECONFIG="$PWD/kubeconfig"
```

## 2. Upload Model

```bash
export HF_TOKEN="..."
export LINODE_BUCKET="$(tofu output -raw object_storage_bucket_name)"
export LINODE_ENDPOINT="$(tofu output -raw object_storage_endpoint)"
export LINODE_ACCESS_KEY="$(tofu output -raw object_storage_access_key)"
export LINODE_SECRET_KEY="$(tofu output -raw object_storage_secret_key)"
export MODEL_OBJECT_KEY="models/qwen2.5-14b-instruct-q4_k_m.gguf"

# Verify exports
echo "HF_TOKEN=$HF_TOKEN"
echo "LINODE_BUCKET=$LINODE_BUCKET"
echo "LINODE_ENDPOINT=$LINODE_ENDPOINT"
echo "LINODE_ACCESS_KEY=$LINODE_ACCESS_KEY"
echo "LINODE_SECRET_KEY=$LINODE_SECRET_KEY"
echo "MODEL_OBJECT_KEY=$MODEL_OBJECT_KEY"

uv run scripts/upload_model.py
```

## 3. Run Benchmark

```bash
export KUBECONFIG="$PWD/kubeconfig"
export LINODE_BUCKET="$(tofu output -raw object_storage_bucket_name)"
export LINODE_ENDPOINT="$(tofu output -raw object_storage_endpoint)"
export LINODE_ACCESS_KEY="$(tofu output -raw object_storage_access_key)"
export LINODE_SECRET_KEY="$(tofu output -raw object_storage_secret_key)"
export MODEL_OBJECT_KEY="models/qwen2.5-14b-instruct-q4_k_m.gguf"

# Verify exports
echo "KUBECONFIG=$KUBECONFIG"
echo "LINODE_BUCKET=$LINODE_BUCKET"
echo "LINODE_ENDPOINT=$LINODE_ENDPOINT"
echo "LINODE_ACCESS_KEY=$LINODE_ACCESS_KEY"
echo "LINODE_SECRET_KEY=$LINODE_SECRET_KEY"
echo "MODEL_OBJECT_KEY=$MODEL_OBJECT_KEY"

bash scripts/run-benchmark.sh
```

## 4. Inspect Results

```bash
ls benchmark-results
cat benchmark-results/*/summary.csv
```

Use pod logs under the same results directory to inspect model load messages from `llama.cpp`.
