#!/bin/bash

set -e

echo "========================================="
echo "Starting Dual Stack VLAN/VPC Deployment"
echo "========================================="
echo ""

if [ -z "$LINODE_TOKEN" ]; then
    echo "Error: LINODE_TOKEN environment variable is not set"
    echo "Please export your Linode API token:"
    echo "  export LINODE_TOKEN='your-token-here'"
    exit 1
fi

echo "Step 1: Initializing OpenTofu..."
tofu init
echo ""

echo "Step 2: Planning resources..."
tofu plan
echo ""

echo "Step 3: Applying resources..."
tofu apply -auto-approve
echo ""

echo "========================================="
echo "Infrastructure deployment completed"
echo "========================================="
echo ""
echo "Topology:"
tofu output -raw topology_summary
echo ""
echo "SSH Commands:"
tofu output -raw ssh_command
echo ""
echo "Root Password: $(tofu output -raw ssh_root_password)"
echo ""
echo "Next step:"
echo "  tofu output -raw nat_gateway_commands"
