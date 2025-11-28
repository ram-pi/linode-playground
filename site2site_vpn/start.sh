#!/bin/bash

set -e  # Exit on error

echo "========================================="
echo "Starting Site2Site VPN Deployment"
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
echo "SSH to Gateway Hosts:"
tofu output -raw ssh_command
echo "Password for host-site-1 and host-site-2:"
tofu output -raw host_root_password
echo ""
echo ""

echo "Note: The bastion host provides secure access to your database infrastructure."
echo "      SSH keys are stored in /tmp/id_rsa"
echo ""

# Wait for hosts to be ready
echo "Step 3: Waiting 60 seconds for hosts to complete cloud-init..."
for i in {60..1}; do
    printf "\rTime remaining: %02d seconds" $i
    sleep 1
done
echo ""
echo ""

# Create ansible configuration files and print command to run playbook
echo "Creating Ansible configuration files..."
tofu output -raw ansible_host_ini > ./vpn-setup/hosts.ini

echo "To configure the VPN gateways, run the following command:"
echo "ansible-playbook -i vpn-setup/hosts.ini vpn-setup/site-to-site.yaml"
