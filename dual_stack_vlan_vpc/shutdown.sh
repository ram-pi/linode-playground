#!/bin/bash

set -e

echo "========================================="
echo "Shutting Down Dual Stack VLAN/VPC Resources"
echo "========================================="
echo ""

read -p "Are you sure you want to destroy all resources? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Shutdown cancelled."
    exit 0
fi

echo ""
echo "Running tofu destroy..."
tofu destroy -auto-approve

echo ""
echo "Cleaning local OpenTofu and state files..."
rm -rf .terraform .terraform.lock.hcl .tofu .tofu.lock.hcl terraform.tfstate terraform.tfstate.backup

echo "Cleaning generated SSH keys..."
rm -f /tmp/id_rsa /tmp/id_rsa.pub

echo ""
echo "========================================="
echo "Cleanup complete"
echo "========================================="
