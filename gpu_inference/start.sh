#!/bin/bash

set -e  # Exit on error

echo "========================================="
echo "Starting Deployment"
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
echo "SSH to Host:"
tofu output -raw ssh_command
echo ""
echo ""

echo "Note: The host provides secure access to your database infrastructure."
echo "      SSH keys are stored in /tmp/id_rsa"
echo ""

echo "You can monitor cloud-init progress by SSHing into the bastion host and checking the cloud-init logs:"
echo " tail -f /var/log/cloud-init-output.log"
echo ""
echo "Bastion host should be ready now!"
echo "Check nvidia-smi output by SSHing into the bastion host:"
echo "nvidia-smi"
HOST_METRICS=$(tofu output -raw scraping_target)
echo "Check GPU metrics endpoint by running the following command on your local machine:"
echo "curl http://$HOST_METRICS"
echo ""

# Step 4: Configure and Start Monitoring (Optional)
echo ""
read -p "Do you want to configure and start monitoring (docker required)? (y/n) " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "========================================="
    echo "Step 4: Configuring Monitoring"
    echo "========================================="
    echo ""

    # Generate prometheus.yml from template + terraform output
    echo "Generating Prometheus configuration..."
    cp monitoring/prometheus.yml.template monitoring/prometheus.yml

    # Append the scrape config from terraform output
    SCRAPE_CONFIG=$(tofu output -raw prometheus_scrape_config)
    echo "$SCRAPE_CONFIG" >> monitoring/prometheus.yml
    echo "✓ Prometheus configuration generated"
    echo ""

    # Start monitoring stack
    echo "Starting monitoring stack (Prometheus + Grafana)..."
    cd monitoring
    docker-compose up -d
    cd ..
    echo ""

    echo "========================================="
    echo "Monitoring Stack Started!"
    echo "========================================="
    echo ""
    echo "Scraping Target: $(tofu output -raw scraping_target)"
    echo ""
    echo "Access Prometheus: http://localhost:9090"
    echo "Access Grafana:    http://localhost:3000"
    echo ""
    echo "NVIDIA GPU metrics will be scraped every 1 minute"
    echo ""
else
    echo "Skipping monitoring setup."
    echo ""
fi
