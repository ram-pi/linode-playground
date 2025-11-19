#!/bin/bash

set -e  # Exit on error

echo "========================================="
echo "Starting Static Website Deployment"
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

# Step 4: Generate rclone configuration
echo "Step 4: Generating rclone configuration..."
tofu output -raw rclone_config > rclone.conf
echo "✓ Created rclone.conf"
echo ""

# Step 5: Sync buckets with rclone
echo "Step 5: Syncing buckets with rclone..."
RCLONE_CMD=$(tofu output -raw rclone_cmd)
eval "$RCLONE_CMD"
echo ""

# Step 6: Display website endpoints
echo "Step 6: Website deployed successfully!"
echo ""
echo "========================================="
echo "Website Endpoints:"
echo "========================================="
tofu output -raw website_endpoint
echo ""

echo "========================================="
echo "Test the website with:"
echo "========================================="
tofu output -raw website_endpoint | grep "curl"
echo ""
echo "========================================="
echo "Deployment Complete!"
echo "========================================="
