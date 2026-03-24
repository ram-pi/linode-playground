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
echo "Step 1: Initializing OpenTofu..."
tofu init
echo ""

# Step 2: Run Terraform Plan
echo "Step 2: Running tofu plan..."
tofu plan
echo ""

# Step 3: Run Terraform Apply
echo "Step 3: Running tofu apply..."
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
echo "PostgreSQL VM quick checks:"
echo "  SSH command:"
echo "    $(tofu output -raw postgres_vm_direct_ssh_command)"
echo ""
echo "  Tail cloud-init logs:"
echo "    $(tofu output -raw postgres_vm_direct_cloud_init_logs_command)"
echo ""
echo "  Check PostgreSQL service + listening port:"
echo "    $(tofu output -raw postgres_vm_direct_service_check_command)"
echo ""
echo "  Rerun PostgreSQL bootstrap script manually (if needed):"
echo "    $(tofu output -raw postgres_vm_manual_bootstrap_command)"
echo ""
echo "  Show recent PostgreSQL bootstrap/service logs (last 100 lines):"
echo "    $(tofu output -raw postgres_vm_debug_recent_logs_command)"
echo ""
