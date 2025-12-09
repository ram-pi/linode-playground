#!/bin/bash

set -e  # Exit on error

echo "========================================="
echo "Starting LKE AI Capabilities Demo Deployment"
echo "========================================="
echo ""

# Check if LINODE_TOKEN is set
if [ -z "$LINODE_TOKEN" ]; then
    echo "Error: LINODE_TOKEN environment variable is not set"
    echo "Please export your Linode API token:"
    echo "  export LINODE_TOKEN='your-token-here'"
    exit 1
fi

# Prerequisite: run the python script to train models first
# Run the training script
echo "Training NLP models..."
# manage project and its dependencies in a virtual environment, create and activate it
python3 -m venv training/venv
source training/venv/bin/activate
pip install --upgrade pip
pip install -r training/requirements.txt
python3 training/train_nlp_models.py
echo "✓ NLP models trained and saved to models/ directory"
echo ""

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

# Step 4: Save kubeconfig
echo "Step 4: Saving kubeconfig..."
tofu output -json lke_kubeconfig | jq > kubeconfig
echo "✓ Kubeconfig saved to kubeconfig"
echo ""

# Step 5: Wait for LKE cluster to be ready
echo "Step 5: Waiting for LKE cluster to be ready..."
export KUBECONFIG=$(pwd)/kubeconfig
echo "Checking cluster nodes..."
for i in {1..30}; do
    if kubectl get nodes &> /dev/null && [ $(kubectl get nodes --no-headers | grep " Ready" | wc -l) -ge 1 ]; then
        echo "✓ LKE cluster is ready!"
        kubectl get nodes
        break
    fi
    echo "  Attempt $i: Cluster not ready yet. Retrying in 10 seconds..."
    sleep 10
done
echo ""

# Step 6: Run post-installation script
echo "Step 6: Running post-installation script..."
bash scripts/post_installation.sh
echo ""

echo "========================================="
echo "LKE AI Capabilities Deployment Complete!"
echo "========================================="
