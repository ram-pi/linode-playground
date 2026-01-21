#!/bin/bash

set -e  # Exit on error

echo "========================================="
echo "Starting Deployment"
echo "========================================="
echo ""

# Check if LINODE_TOKEN is set
if [ -z "$LINODE_TOKEN" ]; then
    echo "Error: LINODE_TOKEN environment variable is not set"
    echo "Please export your Linode API token:"
    echo "  export LINODE_TOKEN='your-token-here'"
    exit 1
fi

# Step 1: Initialize Terraform
echo "Step 1: Initializing OpenTofu..."
tofu init
echo ""

# Step 2: Run Terraform Plan
echo "Step 2: Running tofu plan..."
tofu plan
echo ""

# Step 3: Run Terraform Apply
echo "Step 3: Running tofu apply..."
tofu apply -target=linode_lke_cluster.main -auto-approve
tofu apply -auto-approve
echo ""

echo "========================================="
echo "Deployment completed successfully!"
echo "========================================="
echo ""

# To check additional outputs
echo "Tofu Outputs:"
tofu output
echo ""

# Check cloud-init logs for any issues
echo "Check cloud-init logs for any issues on the instance using the following command:"
echo "tail -f /var/log/cloud-init*.log"
echo ""

# In case of LKE clusters, provide instructions to get kubeconfig
echo "If you have deployed an LKE cluster, retrieve the kubeconfig file using:"
echo "tofu output -raw lke_kubeconfig > kubeconfig"
echo "Then set the KUBECONFIG environment variable:"
echo "export KUBECONFIG=$(pwd)/kubeconfig"
echo "You can then interact with your cluster using kubectl."
echo ""
