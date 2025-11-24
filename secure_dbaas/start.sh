#!/bin/bash

set -e  # Exit on error

echo "========================================="
echo "Starting Secure DBaaS Deployment"
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

# Wait for bastion host to be ready
echo "Step 4: Waiting 60 seconds for bastion host to complete cloud-init..."
for i in {60..1}; do
    printf "\rTime remaining: %02d seconds" $i
    sleep 1
done
echo ""
echo ""

echo "========================================="
echo "Deployment completed successfully!"
echo "========================================="
echo ""

# Display connection information
echo "SSH to Bastion Host:"
tofu output -raw ssh_command
echo ""
echo ""

echo "Note: The bastion host provides secure access to your database infrastructure."
echo "      SSH keys are stored in /tmp/id_rsa"
echo ""

# Print the database connection commands
echo "Database Connection Details:"
tofu output -raw psql_connect_command
echo ""
echo "Note: Use the bastion host to securely connect to your database instances."
echo ""
