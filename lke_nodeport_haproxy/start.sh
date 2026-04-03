#!/bin/bash

set -e

echo "========================================="
echo "Phase 1: Infrastructure Deployment"
echo "LKE + HAProxy VM + Client VM"
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

echo "Step 3: Applying infrastructure (multi-step)..."
tofu apply -target=linode_instance.proxy -auto-approve -var "linode_token=$LINODE_TOKEN"
tofu apply -target=linode_instance.client -auto-approve -var "linode_token=$LINODE_TOKEN"
tofu apply -target=linode_firewall.proxy -auto-approve -var "linode_token=$LINODE_TOKEN"
tofu apply -target=linode_firewall.client -auto-approve -var "linode_token=$LINODE_TOKEN"
tofu apply -auto-approve -var "linode_token=$LINODE_TOKEN"
echo ""

echo "========================================="
echo "Phase 1 complete — infrastructure ready"
echo "========================================="
echo ""

tofu output
echo ""
echo "Next: follow MANUAL_DEPLOYMENT.md"
echo "to deploy the hello service and wire HAProxy to LKE NodePort."
