#!/bin/bash

set -e

echo "========================================="
echo "Shutting Down Object Storage Signed URL Demo"
echo "========================================="
echo ""

read -p "Are you sure you want to destroy all resources? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Shutdown cancelled."
    exit 0
fi

if [ -z "$LINODE_TOKEN" ]; then
    echo "Error: LINODE_TOKEN environment variable is not set"
    echo "Please export your Linode API token:"
    echo "  export LINODE_TOKEN='your-token-here'"
    exit 1
fi

echo "Stopping local Flask server if running..."
pkill -f "uv run app.py" >/dev/null 2>&1 || true
pkill -f "python3 app.py" >/dev/null 2>&1 || true
echo ""

echo "Attempting to empty Object Storage bucket before destroy..."
if tofu output -raw bucket_label >/dev/null 2>&1; then
    LINODE_BUCKET=$(tofu output -raw bucket_label)
    LINODE_REGION=$(tofu output -raw bucket_region)
    LINODE_S3_ENDPOINT=$(tofu output -raw s3_endpoint)
    LINODE_ACCESS_KEY=$(tofu output -raw access_key)
    LINODE_SECRET_KEY=$(tofu output -raw secret_key)

    if command -v uv >/dev/null 2>&1; then
        export LINODE_BUCKET LINODE_REGION LINODE_S3_ENDPOINT LINODE_ACCESS_KEY LINODE_SECRET_KEY
        uv run python scripts/empty_bucket.py
    else
        echo "Warning: uv not found, skipping bucket object cleanup."
        echo "Install uv or manually empty bucket before running destroy."
    fi
else
    echo "No OpenTofu state outputs found. Skipping bucket cleanup step."
fi
echo ""

echo "Destroying infrastructure..."
tofu destroy -auto-approve
echo ""

echo "Cleaning up local OpenTofu state files..."
rm -rf .terraform .terraform.lock.hcl .tofu .tofu.lock.hcl terraform.tfstate terraform.tfstate.backup
echo ""

echo "========================================="
echo "Cleanup completed"
echo "========================================="
