#!/bin/bash
# Create a GCP GCS bucket and service account
# Requirements:
#   - gcloud CLI installed
#   - Authenticated to GCP (gcloud auth login)
#   - Project ID set (gcloud config set project PROJECT_ID)

set -euo pipefail

# Configuration
GCS_BUCKET_NAME="${1:-lke-bucket-mount-gcs}"
GCS_REGION="${2:-us-central1}"
SERVICE_ACCOUNT_NAME="${3:-lke-bucket-mount-sa}"
PROJECT_ID="${4:-}"

if [ -z "$PROJECT_ID" ]; then
  PROJECT_ID=$(gcloud config get-value project)
  if [ -z "$PROJECT_ID" ]; then
    echo "Error: GCP PROJECT_ID not set. Set it with:"
    echo "  gcloud config set project <PROJECT_ID>"
    exit 1
  fi
fi

echo "=== Creating GCP GCS Bucket and Service Account ==="
echo "Project: $PROJECT_ID"
echo "Bucket: $GCS_BUCKET_NAME"
echo "Region: $GCS_REGION"
echo "Service Account: $SERVICE_ACCOUNT_NAME"
echo ""

SERVICE_ACCOUNT_EMAIL="${SERVICE_ACCOUNT_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

# Create bucket
echo "Creating GCS bucket..."
gcloud storage buckets create "gs://${GCS_BUCKET_NAME}" \
  --project="$PROJECT_ID" \
  --location="$GCS_REGION" \
  --uniform-bucket-level-access || echo "Bucket may already exist, continuing..."

# Create service account (idempotent)
echo "Ensuring service account exists..."
if ! gcloud iam service-accounts describe "$SERVICE_ACCOUNT_EMAIL" --project="$PROJECT_ID" >/dev/null 2>&1; then
  gcloud iam service-accounts create "$SERVICE_ACCOUNT_NAME" \
    --display-name="LKE GCS Bucket Mount" \
    --project="$PROJECT_ID"
fi

# Wait for IAM propagation to avoid immediate "service account does not exist" errors
echo "Waiting for service account propagation..."
for _ in $(seq 1 20); do
  if gcloud iam service-accounts describe "$SERVICE_ACCOUNT_EMAIL" --project="$PROJECT_ID" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

gcloud iam service-accounts describe "$SERVICE_ACCOUNT_EMAIL" --project="$PROJECT_ID" >/dev/null

# Grant bucket-level role (avoids project IAM condition constraints)
echo "Granting bucket-level role..."
gcloud storage buckets add-iam-policy-binding "gs://${GCS_BUCKET_NAME}" \
  --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" \
  --role="roles/storage.objectAdmin"

# Create and export key
echo "Creating service account key..."
KEY_FILE="gcs-sa-key-${SERVICE_ACCOUNT_NAME}.json"
rm -f "$KEY_FILE"
gcloud iam service-accounts keys create "$KEY_FILE" \
  --iam-account="$SERVICE_ACCOUNT_EMAIL" \
  --project="$PROJECT_ID"

echo ""
echo "=== Success ==="
echo "GCS Bucket: $GCS_BUCKET_NAME"
echo "Service Account: $SERVICE_ACCOUNT_EMAIL"
echo "Key File: $KEY_FILE"
echo ""
echo "Next steps:"
echo "  1. Store $KEY_FILE securely"
echo "  2. Create a Kubernetes Secret from the key:"
echo "     kubectl create secret generic gcs-sa-key --from-file=key.json=$KEY_FILE"
