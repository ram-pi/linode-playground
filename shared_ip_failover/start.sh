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
tofu apply -auto-approve
echo ""

echo "========================================="
echo "Deployment completed successfully!"
echo "========================================="
echo ""

# Display connection information
echo "SSH to Bastion Host:"
tofu output -raw ssh_command
echo "SSH Root Password: $(tofu output -raw ssh_root_password)"
echo ""
echo ""

echo "Note: The bastion host provides secure access to your database infrastructure."
echo "      SSH keys are stored in /tmp/id_rsa"
echo ""

echo "========================================="
echo "Infrastructure Deployment Complete!"
echo "========================================="
echo ""
echo "Next Steps:"
echo "  1. Configure hosts: ./configure-hosts.sh"
echo "  2. Deploy HAProxy load balancers: ./deploy-haproxy.sh"
echo "  3. Test the setup"
echo ""
