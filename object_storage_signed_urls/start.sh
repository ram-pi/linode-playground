#!/bin/bash

set -e

echo "========================================="
echo "Starting Object Storage Signed URL Demo"
echo "========================================="
echo ""

if [ -z "$LINODE_TOKEN" ]; then
    echo "Error: LINODE_TOKEN environment variable is not set"
    echo "Please export your Linode API token:"
    echo "  export LINODE_TOKEN='your-token-here'"
    exit 1
fi

echo "Step 1: Initializing OpenTofu..."
tofu init
echo ""

echo "Step 2: Applying infrastructure..."
tofu apply -auto-approve
echo ""

echo "Step 3: Exporting runtime variables from tofu outputs..."
LINODE_BUCKET=$(tofu output -raw bucket_label)
LINODE_REGION=$(tofu output -raw bucket_region)
LINODE_S3_ENDPOINT=$(tofu output -raw s3_endpoint)
LINODE_ACCESS_KEY=$(tofu output -raw access_key)
LINODE_SECRET_KEY=$(tofu output -raw secret_key)
export LINODE_BUCKET
export LINODE_REGION
export LINODE_S3_ENDPOINT
export LINODE_ACCESS_KEY
export LINODE_SECRET_KEY
export FLASK_PORT=${FLASK_PORT:-5000}

echo "Bucket: ${LINODE_BUCKET}"
echo "Region: ${LINODE_REGION}"
echo "Endpoint: ${LINODE_S3_ENDPOINT}"
echo "Flask port: ${FLASK_PORT}"
echo ""

RUNTIME_ENV_FILE=".runtime.env"
printf "export LINODE_BUCKET=%q\n" "${LINODE_BUCKET}" > "${RUNTIME_ENV_FILE}"
printf "export LINODE_REGION=%q\n" "${LINODE_REGION}" >> "${RUNTIME_ENV_FILE}"
printf "export LINODE_S3_ENDPOINT=%q\n" "${LINODE_S3_ENDPOINT}" >> "${RUNTIME_ENV_FILE}"
printf "export LINODE_ACCESS_KEY=%q\n" "${LINODE_ACCESS_KEY}" >> "${RUNTIME_ENV_FILE}"
printf "export LINODE_SECRET_KEY=%q\n" "${LINODE_SECRET_KEY}" >> "${RUNTIME_ENV_FILE}"
printf "export FLASK_PORT=%q\n" "${FLASK_PORT}" >> "${RUNTIME_ENV_FILE}"
echo "Runtime environment written to ${RUNTIME_ENV_FILE}"
echo ""

echo "Step 4: Setting up Python virtual environment..."
if ! command -v uv >/dev/null 2>&1; then
    echo "Error: uv is not installed"
    echo "Install it from: https://docs.astral.sh/uv/getting-started/installation/"
    exit 1
fi

uv venv
uv sync
echo ""

echo "Step 5: Infrastructure and dependencies are ready"
echo "To run the API manually (per MANUAL_DEPLOYMENT.md):"
echo "  source ./${RUNTIME_ENV_FILE}"
echo "  uv run app.py"
echo ""
echo "When running, the API will be available at http://127.0.0.1:${FLASK_PORT}"
echo "Use ./shutdown.sh when you want to destroy infrastructure."
echo ""
