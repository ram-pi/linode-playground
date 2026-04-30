#!/bin/bash
set -e

cd "$(dirname "$0")" || exit 1

echo "=== Phase 1: Provisioning LKE cluster and Object Storage bucket ==="
echo ""
echo "Prerequisites:"
echo "  - Linode CLI: https://github.com/linode/linode-cli"
echo "  - tofu/terraform"
echo ""

# Check if .env.local exists for token
if [ ! -f ".env.local" ]; then
  echo "Please create .env.local with your Linode token:"
  echo "  export LINODE_TOKEN=<your-token>"
  exit 1
fi

source .env.local

if [ -z "$LINODE_TOKEN" ]; then
  echo "LINODE_TOKEN not set in .env.local"
  exit 1
fi

echo "Starting Terraform initialization and apply..."
tofu init
tofu apply -auto-approve

echo ""
echo "=== Phase 1 Complete ==="
echo ""
echo "Run Phase 2 (Kubernetes setup):"
echo "  source .env.local"
echo "  bash MANUAL_DEPLOYMENT.md"
