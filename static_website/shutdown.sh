#!/bin/bash

set -e  # Exit on error

echo "========================================="
echo "Shutting Down OpenTofu Resources"
echo "========================================="
echo ""

# Confirm destruction
read -p "Are you sure you want to destroy all resources? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Shutdown cancelled."
    exit 0
fi

echo "Emptying S3 buckets first..."
delete_cmd=$(terraform output -json | jq -r '.s3cmd_delete_recursive.value')
if [ -n "$delete_cmd" ] && [ "$delete_cmd" != "null" ]; then
    echo "Running: $delete_cmd"
    eval "$delete_cmd"
    echo "✓ Buckets emptied successfully"
    terraform state rm linode_object_storage_object.index
    terraform state rm linode_object_storage_object.not_found
else
    echo "⚠ No bucket deletion command found in outputs"
fi

echo ""
echo "Running tofu destroy..."
tofu destroy -auto-approve

echo ""
echo "Cleaning up OpenTofu files..."
rm -rf .terraform .terraform.lock.hcl .tofu .tofu.lock.hcl terraform.tfstate* terraform.tfstate.backup rclone.conf
echo "✓ Removed .terraform and .tofu directories"
echo "✓ Removed .terraform.lock.hcl and .tofu.lock.hcl"
echo "✓ Removed terraform.tfstate files"

echo ""
echo "========================================="
echo "All resources and files have been cleaned"
echo "========================================="
