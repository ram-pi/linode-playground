#!/bin/bash
set -e

cd "$(dirname "$0")" || exit 1

echo "=== Destroying LKE cluster and Object Storage bucket ==="

read -p "Are you sure? This will delete all resources. (yes/no): " -r REPLY
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
  echo "Aborted."
  exit 1
fi

# Empty Linode Object Storage bucket first so tofu destroy can delete it.
echo ""
echo "=== Pre-cleanup: Linode Object Storage bucket ==="
LINODE_BUCKET=$(tofu output -raw object_storage_bucket_name 2>/dev/null || true)
LINODE_ENDPOINT=$(tofu output -raw object_storage_endpoint 2>/dev/null || true)
LINODE_ACCESS_KEY=$(tofu output -raw object_storage_access_key 2>/dev/null || true)
LINODE_SECRET_KEY=$(tofu output -raw object_storage_secret_key 2>/dev/null || true)

EMPTY_BUCKET_SCRIPT="../object_storage_signed_urls/scripts/empty_bucket.py"
OBJECT_SIGNED_URLS_VENV="../object_storage_signed_urls/.venv/bin/python"

if [[ -n "${LINODE_BUCKET}" && -n "${LINODE_ENDPOINT}" && -n "${LINODE_ACCESS_KEY}" && -n "${LINODE_SECRET_KEY}" && -f "${EMPTY_BUCKET_SCRIPT}" ]]; then
  export LINODE_BUCKET
  export LINODE_S3_ENDPOINT="${LINODE_ENDPOINT#https://}"
  export LINODE_ACCESS_KEY
  export LINODE_SECRET_KEY

  echo "Emptying Linode bucket '${LINODE_BUCKET}'..."
  if [[ -x "${OBJECT_SIGNED_URLS_VENV}" ]]; then
    "${OBJECT_SIGNED_URLS_VENV}" "${EMPTY_BUCKET_SCRIPT}"
  else
    python3 "${EMPTY_BUCKET_SCRIPT}"
  fi
else
  echo "Skipping Linode bucket empty step (missing outputs, credentials, or helper script)."
fi

# Delete GCS bucket if present (created manually in this demo).
echo ""
echo "=== Pre-cleanup: Google Cloud Storage bucket ==="
GCS_BUCKET="${GCS_BUCKET:-${GCS_BUCKET_NAME:-lke-bucket-mount-gcs}}"
if command -v gcloud >/dev/null 2>&1; then
  if gcloud storage ls "gs://${GCS_BUCKET}/" >/dev/null 2>&1; then
    echo "Deleting GCS bucket 'gs://${GCS_BUCKET}' (including objects)..."
    gcloud storage rm -r "gs://${GCS_BUCKET}"
  else
    echo "GCS bucket 'gs://${GCS_BUCKET}' not found or not accessible. Skipping."
  fi
else
  echo "gcloud CLI not found. Skipping GCS bucket deletion."
fi

tofu destroy -auto-approve

echo "=== Destroy Complete ==="
