#!/bin/bash
# Test connectivity to both buckets from the cluster

set -e

cd "$(dirname "$0")/.." || exit 1

# Export Linode outputs
export LINODE_BUCKET=$(tofu output -raw object_storage_bucket_name)
export LINODE_ENDPOINT=$(tofu output -raw object_storage_endpoint)
export LINODE_ACCESS_KEY=$(tofu output -raw object_storage_access_key)
export LINODE_SECRET_KEY=$(tofu output -raw object_storage_secret_key)

echo "=== Testing Bucket Mounts ==="
echo ""

echo "1. Testing Linode Object Storage mount..."
kubectl exec -it deployment/linode-bucket-mount -- bash -c "
  ls -la /mnt/linode-bucket/
  echo 'Linode bucket mount: OK'
"

echo ""
echo "2. Testing GCP GCS mount..."
kubectl exec -it pod/gcs-bucket-manual -- bash -c "
  ls -la /mnt/gcs-bucket/
  echo 'GCS bucket mount: OK'
"

echo ""
echo "=== All bucket mounts are working ==="
