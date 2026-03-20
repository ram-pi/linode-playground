#!/usr/bin/env bash

set -euo pipefail

echo "========================================="
echo "Shutting Down NAT Gateway WireGuard Demo"
echo "========================================="
echo ""

read -r -p "Are you sure you want to destroy all resources? (yes/no): " confirm

if [[ "${confirm}" != "yes" ]]; then
  echo "Shutdown cancelled."
  exit 0
fi

echo ""
echo "Running tofu destroy..."
tofu destroy -auto-approve

echo ""
echo "Cleaning up local state artifacts..."
rm -rf .terraform .tofu
rm -f .terraform.lock.hcl .tofu.lock.hcl terraform.tfstate terraform.tfstate.backup

echo ""
echo "Cleaning up generated SSH keys..."
rm -f /tmp/id_rsa_nat_gw_wg /tmp/id_rsa_nat_gw_wg.pub

echo ""
echo "========================================="
echo "All resources were destroyed"
echo "========================================="
