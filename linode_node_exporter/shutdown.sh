#!/bin/bash

set -e

echo "========================================="
echo "Shutting Down Linode Node Exporter Demo"
echo "========================================="
echo ""

if command -v tofu >/dev/null 2>&1; then
  TF_BIN="tofu"
elif command -v terraform >/dev/null 2>&1; then
  TF_BIN="terraform"
else
  echo "Error: neither 'tofu' nor 'terraform' is installed"
  exit 1
fi

echo "Using $TF_BIN"
echo ""

read -p "Are you sure you want to destroy all resources? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
  echo "Shutdown cancelled."
  exit 0
fi

echo ""
echo "Running destroy..."
"$TF_BIN" destroy -auto-approve
echo ""

echo "Cleaning local Terraform/OpenTofu files..."
rm -rf .terraform .tofu
rm -f .terraform.lock.hcl .tofu.lock.hcl
rm -f terraform.tfstate terraform.tfstate.backup
echo ""

echo "Cleaning generated SSH keys..."
rm -f /tmp/id_rsa /tmp/id_rsa.pub
echo ""

echo "========================================="
echo "Cleanup completed"
echo "========================================="