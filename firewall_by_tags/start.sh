#!/bin/bash

set -e  # Exit on error

echo "========================================="
echo "Starting OpenTofu Firewall Demo"
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

# Get the curl test command from terraform output
TEST_COMMAND=$(tofu output -raw test_web_server_command 2>/dev/null || echo "")

if [ -z "$TEST_COMMAND" ]; then
    echo "Error: Could not get test command from tofu output"
    exit 1
fi

echo "Test command: $TEST_COMMAND"
echo ""

# Step 4: Test web server connectivity (should timeout with initial firewall)
echo "Step 4: Testing web server connectivity (expecting timeout)..."
if bash -c "$TEST_COMMAND" 2>&1; then
    echo "⚠️  Warning: Web server is already accessible (expected timeout)"
else
    echo "✓ Connection timed out as expected (firewall blocking)"
fi
echo ""

# Step 5: Apply firewall rules using Python script
echo "Step 5: Applying firewall rules with Python script..."
cd apply_linode_firewalls

# Check if virtual environment exists, create if not
if [ ! -d "venv" ] && [ ! -d ".venv" ]; then
    echo "  Creating virtual environment..."
    python3 -m venv venv
    source venv/bin/activate
    echo "  Installing requirements..."
    pip install --upgrade pip
    pip install -r requirements.txt
elif [ -d "venv" ]; then
    source venv/bin/activate
elif [ -d ".venv" ]; then
    source .venv/bin/activate
fi

python3 apply_firewalls_optimized.py

# Deactivate venv if it was activated
if [ -n "$VIRTUAL_ENV" ]; then
    deactivate
fi

cd ..
echo ""

# Step 6: Wait for firewall propagation
echo "Step 6: Waiting 60 seconds for firewall rules to propagate..."
for i in {60..1}; do
    printf "\rTime remaining: %02d seconds" $i
    sleep 1
done
echo ""
echo ""

# Step 7: Test web server connectivity again (expecting success)
echo "Step 7: Testing web server connectivity again (expecting success)..."
echo "$TEST_COMMAND"
if bash -c "$TEST_COMMAND" 2>&1; then
    echo "✓ Successfully connected to web server!"
else
    echo "✗ Connection still blocked - firewall may need more time"
    exit 1
fi
echo ""

echo "========================================="
echo "Demo completed successfully!"
echo "========================================="
echo ""
echo "Test the web server with:"
echo "$TEST_COMMAND"
