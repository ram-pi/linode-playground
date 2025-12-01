#!/bin/bash

set -e  # Exit on error

echo "========================================="
echo "Starting Linode with Multiple Volumes Backup Deployment"
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
echo "SSH to Bastion Host:"
tofu output -raw ssh_command
echo ""
echo ""

echo "Note: The bastion host provides secure access to your database infrastructure."
echo "      SSH keys are stored in /tmp/id_rsa"
echo ""

# Wait for bastion host to be ready
echo "Step 4: Waiting 150 seconds for bastion host to complete cloud-init..."
for i in {150..1}; do
    printf "\rTime remaining: %02d seconds" $i
    sleep 1
done
echo ""
echo ""

# Step 5: run the scp command to copy the backup script to the bastion host (take the command from tofu outputs)
echo "Step 5: Copying backup script to bastion host..."
SCP_COMMAND=$(tofu output -raw scp_backup_script_command)
eval "$SCP_COMMAND"
echo "✓ Backup script copied to bastion host"
echo ""

# Step 6: run the "backup.sh" script on the bastion host via SSH (take the command from tofu outputs)
echo "Step 6: Executing backup script on bastion host..."
SSH_COMMAND=$(tofu output -raw script_env_vars)
echo "$SSH_COMMAND"
echo "✓ Backup script executed on bastion host"
echo ""
echo "========================================="
echo "Backup Process Completed!"
echo "========================================="
echo ""
echo "You can access the rclone web UI at:"
tofu output -raw rclone_endpoints
echo ""
echo "========================================="
echo "Deployment Complete!"
echo "========================================="
