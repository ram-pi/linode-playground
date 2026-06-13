#!/usr/bin/env bash

set -euo pipefail

echo "========================================="
echo "Starting LKE Distributed Inference Setup"
echo "========================================="
echo ""

if [[ -z "${LINODE_TOKEN:-}" ]]; then
  echo "Error: LINODE_TOKEN environment variable is not set"
  echo "Example: export LINODE_TOKEN='your-linode-api-token'"
  exit 1
fi

if ! command -v tofu >/dev/null 2>&1; then
  echo "Error: tofu command not found"
  exit 1
fi

echo "Step 1: Initializing OpenTofu"
tofu init
echo ""

echo "Step 2: Planning infrastructure"
tofu plan -out=tfplan
echo ""

echo "Step 3: Applying infrastructure"
tofu apply -auto-approve tfplan
echo ""

echo "Step 4: Writing kubeconfig files"
tofu output -raw lon_kubeconfig | base64 -d > kubeconfig-gb-lon
tofu output -raw fra_kubeconfig | base64 -d > kubeconfig-de-fra-2
tofu output -raw sea_kubeconfig | base64 -d > kubeconfig-us-sea
chmod 600 kubeconfig-gb-lon kubeconfig-de-fra-2 kubeconfig-us-sea
echo "  - kubeconfig-gb-lon  (Karmada control plane)"
echo "  - kubeconfig-de-fra-2"
echo "  - kubeconfig-us-sea"
echo ""

cat <<'EOF'
=========================================
Provisioning complete
=========================================

Next steps:
1. Follow MANUAL_DEPLOYMENT.md to install Karmada + KubeRay.
2. Set context to gb-lon (Karmada host):
   export KUBECONFIG=$PWD/kubeconfig-gb-lon
3. Verify nodes:
   kubectl get nodes -o wide
EOF
