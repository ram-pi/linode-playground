#!/bin/bash

set -e

echo "========================================="
echo "Phase 1: Infrastructure Deployment"
echo "LKE + FRP Server + VLAN Networking"
echo "========================================="
echo ""

if [ -z "$LINODE_TOKEN" ]; then
    echo "Error: LINODE_TOKEN environment variable is not set"
    echo "  export LINODE_TOKEN='your-token-here'"
    exit 1
fi

echo "Step 1: Initializing OpenTofu..."
tofu init
echo ""

echo "Step 2: Planning resources..."
tofu plan -var "linode_token=$LINODE_TOKEN"
echo ""

echo "Step 3: Applying infrastructure..."
tofu apply -auto-approve -var "linode_token=$LINODE_TOKEN"
echo ""

echo "========================================="
echo "Phase 1 complete — infrastructure ready"
echo "========================================="
echo ""

tofu output
echo ""
echo "Next: follow Phase 2 in MANUAL_DEPLOYMENT.md"
echo "to install Helm charts and deploy FRP workloads."
