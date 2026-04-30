# Manual Deployment Runbook

This document covers **Phase 2**: installing CSI drivers and deploying bucket-mount workloads on the LKE cluster provisioned in Phase 1 (`./start.sh`).

## Prerequisites

| Tool | Install |
|------|---------|
| `kubectl` | `brew install kubectl` or [official docs](https://kubernetes.io/docs/tasks/tools/) |
| `helm` | `brew install helm` |
| `envsubst` | included in `gettext` — `brew install gettext` (macOS) or `apt-get install gettext-base` (Ubuntu) |
| `gcloud` | [Google Cloud CLI](https://cloud.google.com/sdk/docs/install) (for GCS bucket creation) |
| `tofu` | already used in Phase 1 |

---

## Step 1 — Export infrastructure outputs

Run these from the `lke-with-bucket-mount/` directory after `./start.sh` completes.

```bash
# Export kubeconfig
tofu output -raw lke_kubeconfig | base64 -d > kubeconfig
export KUBECONFIG=$PWD/kubeconfig

# Verify LKE nodes are Ready before continuing
kubectl get nodes -o wide
# Expected: all nodes in "Ready" state

# Export Object Storage credentials
export LINODE_BUCKET=$(tofu output -raw object_storage_bucket_name)
# csi-s3 expects endpoint as a full URL (for example https://it-mil-1.linodeobjects.com)
export LINODE_ENDPOINT=$(tofu output -raw object_storage_endpoint)
export LINODE_ACCESS_KEY=$(tofu output -raw object_storage_access_key)
export LINODE_SECRET_KEY=$(tofu output -raw object_storage_secret_key)

echo "Linode Object Storage:"
echo "  Bucket: $LINODE_BUCKET"
echo "  Endpoint: $LINODE_ENDPOINT"
echo "  Access Key ID length: ${#LINODE_ACCESS_KEY}"
echo "  Secret Key ID length: ${#LINODE_SECRET_KEY}"
```

---

## Step 2 — Install Cloud Firewall CRDs (Optional)

If you want to manage cluster firewalls through Kubernetes:

```bash
helm repo add cloud-firewall-controller https://linode.github.io/cloud-firewall-controller
helm repo update

helm upgrade --install cloud-firewall-crd \
  cloud-firewall-controller/cloud-firewall-crd \
  --wait --timeout 5m
```

Verify:

```bash
kubectl get crd | grep firewall
# Expected: firewall CRD entries
```

---

## Step 3 — Install Cloud Firewall Controller (Optional)

```bash
helm upgrade --install cloud-firewall \
  cloud-firewall-controller/cloud-firewall-controller \
  --wait --timeout 5m
```

Verify:

```bash
kubectl get pods -A | grep cloud-firewall
# Expected: cloud-firewall pod in Running state
```

---

## Step 4 — Set up Linode Object Storage access

This demo uses the default namespace for workload resources.

Install an S3-compatible CSI driver (not AWS EBS CSI):

```bash
helm repo add csi-s3 https://yandex-cloud.github.io/k8s-csi-s3/charts
helm repo update

helm upgrade --install csi-s3 csi-s3/csi-s3 \
   --namespace kube-system --create-namespace \
   --set-string secret.accessKey="$LINODE_ACCESS_KEY" \
   --set-string secret.secretKey="$LINODE_SECRET_KEY" \
   --set-string secret.endpoint="$LINODE_ENDPOINT" \
   --set-string storageClass.singleBucket="$LINODE_BUCKET" \
   --wait --timeout 5m
```

Verify:

```bash
kubectl get csidriver ru.yandex.s3.csi
kubectl get pods -n kube-system | grep csi-s3
kubectl get storageclass csi-s3
# Expected: csi-s3 pods in Running state
```

---

## Step 5 — Set up Google Cloud Storage access

### Prerequisites

- GCP Project ID
- `gcloud` CLI authenticated with a service account that has permissions to create resources
- GCS service account JSON key (created by the helper script below)

### Create GCS bucket and service account

```bash
# Set your GCP project ID
export GCP_PROJECT_ID="your-project-id"
export GCS_BUCKET_NAME="lke-bucket-mount-gcs"
export GCS_REGION="us-central1"

# Create bucket and service account
bash scripts/create-gcp-gcs-bucket.sh "$GCS_BUCKET_NAME" "$GCS_REGION" "lke-bucket-mount-sa" "$GCP_PROJECT_ID"
```

After the script completes, it will create a JSON key file:

```
gcs-sa-key-lke-bucket-mount-sa.json
```

### Create Kubernetes secret from GCS key

```bash
# Base64 encode the key
export GCS_SA_KEY_B64=$(base64 -i gcs-sa-key-lke-bucket-mount-sa.json)

# Store the bucket name for later
export GCS_BUCKET=$GCS_BUCKET_NAME

# Create the secret
envsubst < configs/03-gcs-secret.yaml.tpl | kubectl apply -f -
```

Verify:

```bash
kubectl get secret gcs-sa-key
# Expected: gcs-sa-key secret
```

---

## Step 6 — Create Persistent Volume Claim

### Linode Object Storage PVC

```bash
kubectl apply -f configs/05-linode-pvc.yaml
```

Verify:

```bash
kubectl get pvc linode-bucket-pvc
# Expected: PVC in Bound state
```

---

## Step 7 — Deploy example workloads

### Linode Object Storage mount

```bash
kubectl apply -f configs/07-linode-bucket-mount-deployment.yaml

kubectl rollout status deployment/linode-bucket-mount
# Expected: deployment "linode-bucket-mount" successfully rolled out
```

### GCS Bucket mount (manual gcsfuse pod)

```bash
envsubst < configs/09-gcsfuse-manual-pod.yaml.tpl | kubectl apply -f -

kubectl wait --for=condition=Ready pod/gcs-bucket-manual --timeout=300s
# Expected: pod "gcs-bucket-manual" ready
```

---

## Step 8 — Verify bucket mounts

### Test Linode Object Storage

```bash
kubectl exec -it deployment/linode-bucket-mount -- ls -la /mnt/linode-bucket/
```

### Create a test object in Linode Object Storage

```bash
LINODE_TEST_FILE="linode-verify-$(date +%Y%m%d-%H%M%S).txt"
kubectl exec deployment/linode-bucket-mount -- sh -c "echo 'hello from LKE to Linode Object Storage' > /mnt/linode-bucket/$LINODE_TEST_FILE && cat /mnt/linode-bucket/$LINODE_TEST_FILE && ls -l /mnt/linode-bucket/$LINODE_TEST_FILE"
echo "Created object: s3://$LINODE_BUCKET/$LINODE_TEST_FILE"
```

### Test GCS Bucket

```bash
kubectl exec -it pod/gcs-bucket-manual -- ls -la /mnt/gcs-bucket/
```

### Create a test object in GCS

```bash
GCS_TEST_FILE="gcs-verify-$(date +%Y%m%d-%H%M%S).txt"
kubectl exec pod/gcs-bucket-manual -- sh -c "echo 'hello from LKE to Google Cloud Storage' > /mnt/gcs-bucket/$GCS_TEST_FILE && cat /mnt/gcs-bucket/$GCS_TEST_FILE && ls -l /mnt/gcs-bucket/$GCS_TEST_FILE"
echo "Created object: gs://$GCS_BUCKET/$GCS_TEST_FILE"
```

### Verify later from the cloud side

```bash
# Ensure local variables still exist in this shell session
echo "GCS_BUCKET=$GCS_BUCKET"
echo "GCS_TEST_FILE=$GCS_TEST_FILE"

gcloud storage ls "gs://$GCS_BUCKET/$GCS_TEST_FILE"
```

### Run automated test

```bash
bash scripts/test-bucket-mounts.sh
```

---
