#!/bin/bash

set -e

echo "========================================="
echo "Destroying: LVS DR Director + LKE"
echo "========================================="
echo ""

read -p "Are you sure you want to destroy all resources? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Shutdown cancelled."
    exit 0
fi

if [ -z "$LINODE_TOKEN" ]; then
    echo "Error: LINODE_TOKEN environment variable is not set"
    echo "  export LINODE_TOKEN='your-token-here'"
    exit 1
fi

echo "Running tofu destroy..."
tofu destroy -auto-approve -var "linode_token=$LINODE_TOKEN"

echo "Cleaning local files..."
rm -rf .terraform .terraform.lock.hcl terraform.tfstate terraform.tfstate.backup kubeconfig

echo "Done."
