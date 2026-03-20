#!/usr/bin/env bash

set -euo pipefail

echo "========================================="
echo "Starting NAT Gateway Using WireGuard"
echo "========================================="
echo ""

if [[ -z "${LINODE_TOKEN:-}" ]]; then
  echo "Error: LINODE_TOKEN environment variable is not set"
  echo "Please export your Linode API token:"
  echo "  export LINODE_TOKEN='your-token-here'"
  exit 1
fi

echo "Step 1: Initializing OpenTofu..."
tofu init
echo ""

echo "Step 2: Planning deployment..."
tofu plan
echo ""

echo "Step 3: Applying infrastructure..."
tofu apply -auto-approve
echo ""

echo "========================================="
echo "Deployment completed successfully"
echo "========================================="
echo ""

echo "Topology summary:"
tofu output -raw topology_summary
echo ""

echo "NAT gateway SSH command:"
tofu output -raw ssh_nat_gateway
echo ""

echo "Private VM SSH via jump host:"
tofu output -raw ssh_private_via_jump
echo ""

echo "Root password (NAT gateway):"
tofu output -raw nat_gateway_root_password
echo ""

echo "Root password (private VM):"
tofu output -raw private_vm_root_password
echo ""

echo "Proxy bootstrap + WireGuard commands:"
tofu output -raw wireguard_bootstrap_commands
echo ""
