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
kubectl delete -f config/podinfo.dpl.yaml || echo "Podinfo application not found or already deleted"
kubectl delete -f config/echo-ip.dpl.yaml || echo "Echo-ip application not found or already deleted"
helm uninstall apl || echo "Helm release 'apl' not found or already deleted"
helm uninstall cloud-firewall || echo "Helm release 'cloud-firewall' not found or already deleted"
helm uninstall cloud-firewall-crd || echo "Helm release 'cloud-firewall-crd' not found or already deleted"
wait_for_deletions() {
    echo "Waiting for resources to be deleted..."
    sleep 60
}
wait_for_deletions

# delete nodebalancers
echo "Deleting NodeBalancers..."
tofu output -raw loadbalancer_service_conf | kubectl delete -f - || echo "LoadBalancer service not found or already deleted"
wait_for_deletions

echo ""
echo "Running tofu destroy..."
tofu destroy -auto-approve

echo ""
echo "Cleaning up OpenTofu files..."
rm -rf .terraform .terraform.lock.hcl .tofu .tofu.lock.hcl terraform.tfstate terraform.tfstate.backup
echo "✓ Removed .terraform and .tofu directories"
echo "✓ Removed .terraform.lock.hcl and .tofu.lock.hcl"
echo "✓ Removed terraform.tfstate files"

echo ""
echo "Cleaning up kubeconfig..."
if [ -f "kubeconfig.yaml" ]; then
    rm -f kubeconfig.yaml
    echo "✓ Removed kubeconfig.yaml"
fi

echo "Cleaning up firewall rules created by helm chart..."
# Get the LKE cluster ID
CLUSTER_ID=$(linode lke clusters-list --json | jq -r '.[0].id')

if [ -n "$CLUSTER_ID" ]; then
    echo "Found LKE cluster ID: $CLUSTER_ID"

    # Find and delete firewall with label lke-$CLUSTER_ID
    FIREWALL_ID=$(linode firewalls list --json | jq -r ".[] | select(.label == \"lke-$CLUSTER_ID\") | .id")

    if [ -n "$FIREWALL_ID" ]; then
        echo "Deleting firewall $FIREWALL_ID with label lke-$CLUSTER_ID..."
        linode firewalls delete "$FIREWALL_ID"
        echo "✓ Removed firewall rule lke-$CLUSTER_ID"
    else
        echo "No firewall found with label lke-$CLUSTER_ID"
    fi
else
    echo "No LKE cluster found"
fi

echo ""
echo "========================================="
echo "All resources and files have been cleaned"
echo "========================================="
