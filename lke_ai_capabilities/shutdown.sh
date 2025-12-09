#!/bin/bash

set -e  # Exit on error

echo "========================================="
echo "Shutting Down OpenTofu Resources"
echo "========================================="
echo ""

# Confirm destruction
read -p "Are you sure you want to destroy all resources? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Shutdown cancelled."
    exit 0
fi

# Emptying any necessary resources before destruction
echo "Running any necessary pre-destroy cleanup..."
export KUBECONFIG=$(pwd)/kubeconfig
helm uninstall apl || echo "Helm release 'apl' not found or already deleted"
helm uninstall cloud-firewall || echo "Helm release 'cloud-firewall' not found or already deleted"
helm uninstall cloud-firewall-crd || echo "Helm release 'cloud-firewall-crd' not found or already deleted"
wait_for_deletions() {
    echo "Waiting for resources to be deleted..."
    sleep 60
}
wait_for_deletions

echo ""
echo "Running tofu destroy..."
tofu destroy -auto-approve

echo ""
echo "Cleaning up OpenTofu files and generated resources..."
rm -rf .terraform .terraform.lock.hcl .tofu .tofu.lock.hcl terraform.tfstate terraform.tfstate.backup kubeconfig *.joblib
rm -f apl/values.yaml apl/nodebalancer_info.env
echo "✓ Removed .terraform and .tofu directories"
echo "✓ Removed .terraform.lock.hcl and .tofu.lock.hcl"
echo "✓ Removed terraform.tfstate files"
echo "✓ Removed generated values.yaml and nodebalancer_info.env"

echo ""
echo "========================================="
echo "All resources and files have been cleaned"
echo "========================================="
