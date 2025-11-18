#!/bin/bash

set -e  # Exit on error

echo "========================================="
echo "Starting Private VM Demo"
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

# Wait for cloud-init to complete and NAT gateway to be ready
echo "Step 4: Waiting 90 seconds for cloud-init and NAT gateway setup..."
for i in {90..1}; do
    printf "\rTime remaining: %02d seconds" $i
    sleep 1
done
echo ""
echo ""

echo "========================================="
echo "Demo completed successfully!"
echo "========================================="
echo ""

# Display connection information
echo "SSH to Public VM (NAT Gateway):"
tofu output -raw ssh_command
echo ""
echo ""

echo "Access Private VM via LISH:"
tofu output -raw lish_command
echo ""
echo ""

echo "Note: The public VM acts as a NAT gateway, allowing the private VM"
echo "      to access the internet while remaining in a private VPC subnet."
