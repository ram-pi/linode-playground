#!/bin/bash

set -e  # Exit on error

echo "========================================="
echo "Starting Multi-Cluster Deployment"
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
echo "Step 1: Initializing..."
tofu init
echo ""

# Step 2: Run Terraform Plan
echo "Step 2: Running tofu plan..."
tofu plan
echo ""

# Step 3: Run Terraform Apply
echo "Step 3: Running tofu apply..."
tofu apply -target=linode_lke_cluster.cluster_01 -auto-approve
tofu apply -target=linode_lke_cluster.cluster_02 -auto-approve
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

echo "========================================="
echo "Quick Access Commands"
echo "========================================="
echo ""
echo "To access Cluster 01:"
echo "  export KUBECONFIG=./kubeconfig-cluster-01"
echo "  kubectl get nodes"
echo ""
echo "To access Cluster 02:"
echo "  export KUBECONFIG=./kubeconfig-cluster-02"
echo "  kubectl get nodes"
echo ""
echo "To access both clusters:"
echo "  export KUBECONFIG=./kubeconfig-cluster-01:./kubeconfig-cluster-02"
echo "  kubectl config get-contexts"
echo ""
