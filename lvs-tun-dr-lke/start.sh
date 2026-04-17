#!/bin/bash

set -e

echo "========================================="
echo "Deploying: LVS DR Director + LKE"
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
echo "Infrastructure ready"
echo "========================================="
echo ""

tofu output
echo ""
echo "Next: follow MANUAL_DEPLOYMENT.md"
