#!/usr/bin/env bash

set -e  # Exit on error

echo "========================================="
echo "Post-Installation Setup"
echo "========================================="
echo ""

# Get Script Directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

# Ensure KUBECONFIG is set
export KUBECONFIG=$(pwd)/kubeconfig

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl is not installed"
    echo "Please install kubectl first"
    exit 1
fi

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    echo "Error: helm is not installed"
    echo "Please install Helm first"
    exit 1
fi

# Step 1: Install Cloud Firewall Controller
echo "========================================="
echo "Step 1: Installing Cloud Firewall Controller"
echo "========================================="
echo ""
read -p "Proceed with installing Cloud Firewall Controller? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Skipping Cloud Firewall Controller installation"
else
    # Add the Helm repository
    helm repo add linode-cfw https://linode.github.io/cloud-firewall-controller
    helm repo update linode-cfw

    # Install CRD
    helm install cloud-firewall-crd linode-cfw/cloud-firewall-crd

    # Wait for CRD to be established
    kubectl wait --for condition=established --timeout=60s crd/cloudfirewalls.networking.linode.com

    # Install controller
    helm install cloud-firewall linode-cfw/cloud-firewall-controller

    echo "✓ Cloud Firewall Controller installed"
fi
echo ""

# Step 2: Get NodeBalancer information
echo "========================================="
echo "Step 2: Retrieving NodeBalancer Information"
echo "========================================="
echo ""
read -p "Proceed with retrieving NodeBalancer information? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Error: NodeBalancer information is required for the next steps"
    exit 1
fi

# Run get_nodebalancer_info.sh and capture output
OUTPUT=$(bash scripts/get_nodebalancer_info.sh)
echo "$OUTPUT"

# Extract IP and NodeBalancer ID from output
EXTERNAL_IP=$(echo "$OUTPUT" | grep "Temporary service assigned External IP:" | awk '{print $NF}')
NB_ID=$(echo "$OUTPUT" | grep "NodeBalancer ID:" | awk '{print $NF}')

if [ -z "$EXTERNAL_IP" ] || [ -z "$NB_ID" ]; then
    echo "Error: Failed to retrieve External IP or NodeBalancer ID"
    exit 1
fi

echo "✓ Retrieved NodeBalancer IP: $EXTERNAL_IP"
echo "✓ Retrieved NodeBalancer ID: $NB_ID"
echo ""

# Save to file for reference
echo "EXTERNAL_IP=$EXTERNAL_IP" > apl/nodebalancer_info.env
echo "NB_ID=$NB_ID" >> apl/nodebalancer_info.env

# Step 3: Build values.yaml for APL Helm chart
echo "========================================="
echo "Step 3: Building values.yaml for APL"
echo "========================================="
echo ""
read -p "Proceed with building values.yaml? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Error: values.yaml is required for APL installation"
    exit 1
fi

# Get obj block from Terraform output
OBJ_BLOCK=$(tofu output -raw obj_addition_apl_helm)

# Create domain suffix using nip.io
DOMAIN_SUFFIX="${EXTERNAL_IP}.nip.io"

# Build the values.yaml based on no_domain.values.yaml
cat apl/no_domain.values.yaml > apl/values.yaml

# Replace the IP in domainSuffix
sed -i.bak "s|domainSuffix:.*|domainSuffix: ${DOMAIN_SUFFIX}|g" apl/values.yaml

# Replace the NodeBalancer ID
sed -i.bak "s|value: \".*\"|value: \"${NB_ID}\"|g" apl/values.yaml

# Replace the hardcoded IP in the Keycloak health check URL
sed -i.bak "s|https://keycloak\.[0-9.]*\.nip\.io|https://keycloak.${DOMAIN_SUFFIX}|g" apl/values.yaml

# Append the obj block
echo "$OBJ_BLOCK" >> apl/values.yaml

# Clean up backup file
rm -f apl/values.yaml.bak

echo "✓ values.yaml created at apl/values.yaml with:"
echo "  - Domain Suffix: ${DOMAIN_SUFFIX}"
echo "  - NodeBalancer ID: ${NB_ID}"
echo "  - Object Storage configuration added"
echo ""

# Step 4: Install APL Helm chart
echo "========================================="
echo "Step 4: Installing APL Helm Chart"
echo "========================================="
echo ""
read -p "Proceed with installing APL Helm chart? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Skipping APL installation"
    exit 0
fi

# Add APL Helm repository
helm repo add apl https://linode.github.io/apl-core
helm repo update apl

# Install APL
helm install apl apl/apl -f apl/values.yaml

echo "✓ APL Helm chart installed"
echo ""

# Step 5: Wait for APL installation to complete
echo "========================================="
echo "Step 5: Waiting for APL Installation"
echo "========================================="
echo ""
read -p "Wait for APL installation to complete? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Skipping wait, you can check manually with: kubectl get jobs --all-namespaces"
else
    echo "Waiting for APL jobs to complete..."
    # Wait for jobs to be created first
    sleep 30

    # Monitor jobs in all namespaces
    MAX_WAIT=1800  # 30 minutes
    ELAPSED=0
    INTERVAL=30

    while [ $ELAPSED -lt $MAX_WAIT ]; do
        # Check if there are any jobs
        JOBS=$(kubectl get jobs --all-namespaces -o json 2>/dev/null || echo '{"items":[]}')
        TOTAL_JOBS=$(echo "$JOBS" | jq '.items | length')

        if [ "$TOTAL_JOBS" -gt 0 ]; then
            COMPLETED_JOBS=$(echo "$JOBS" | jq '[.items[] | select(.status.succeeded == 1)] | length')
            FAILED_JOBS=$(echo "$JOBS" | jq '[.items[] | select(.status.failed != null and .status.failed > 0)] | length')

            echo "  Jobs status: $COMPLETED_JOBS/$TOTAL_JOBS completed, $FAILED_JOBS failed"

            if [ "$FAILED_JOBS" -gt 0 ]; then
                echo "Warning: Some jobs have failed"
                kubectl get jobs --all-namespaces | grep -i "apl\|otomi" || true
            fi

            # Check if all jobs are completed
            if [ "$COMPLETED_JOBS" -eq "$TOTAL_JOBS" ]; then
                echo "✓ All APL jobs completed successfully!"
                break
            fi
        else
            echo "  No jobs found yet, waiting..."
        fi

        sleep $INTERVAL
        ELAPSED=$((ELAPSED + INTERVAL))
    done

    if [ $ELAPSED -ge $MAX_WAIT ]; then
        echo "Warning: Timeout waiting for APL jobs to complete"
        echo "Installation may still be in progress. Check manually with: kubectl get jobs --all-namespaces"
    fi
fi

echo ""

# Step 6: Print APL information
echo "========================================="
echo "Step 6: APL Information"
echo "========================================="
echo ""

bash scripts/get_apl_info.sh

echo ""
echo "========================================="
echo "Post-Installation Complete!"
echo "========================================="
