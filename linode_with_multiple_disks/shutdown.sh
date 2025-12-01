#!/bin/bash

set -e  # Exit on error

echo "========================================="
echo "Shutting Down Linode with Multiple Volumes Backup Resources"
echo "========================================="
echo ""

# Confirm destruction
read -p "Are you sure you want to destroy all resources? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Shutdown cancelled."
    exit 0
fi

# Cleanup backup files from Object Storage
echo "Emptying Object Storage buckets first..."
delete_cmd=$(tofu output -raw s3cmd_empty_buckets_command)
if [ -n "$delete_cmd" ] && [ "$delete_cmd" != "null" ]; then
    echo "Running: $delete_cmd"
    eval "$delete_cmd"
    echo "✓ Buckets emptied successfully"
fi

echo ""
echo "Running tofu destroy..."
tofu destroy -auto-approve

echo ""
echo "Cleaning up OpenTofu files..."
rm -rf .terraform .terraform.lock.hcl .tofu .tofu.lock.hcl terraform.tfstate terraform.tfstate.backup
echo "✓ Removed .terraform and .tofu directories"
echo "✓ Removed .terraform.lock.hcl and .tofu.lock.hcl"
echo "✓ Removed terraform.tfstate files"

echo ""
echo "Cleaning up SSH keys..."
rm -f /tmp/id_rsa /tmp/id_rsa.pub
echo "✓ Removed SSH keys from /tmp"

echo ""
echo "========================================="
echo "All resources and files have been cleaned"
echo "========================================="
