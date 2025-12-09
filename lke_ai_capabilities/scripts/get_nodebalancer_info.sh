#!/usr/bin/env bash

set -e

# This script creates a temporary Kubernetes Service of type LoadBalancer
# to trigger the creation of a Linode NodeBalancer, retrieves its information,
# and then cleans up the temporary Service.
# service.beta.kubernetes.io/linode-loadbalancer-preserve: "true" this will preserve the NB after svc deletion
# Usage: ./get_nodebalancer_info.sh
# prerequisites: kubectl configured to access the target cluster, linode-cli installed and configured

# Get Script Directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

# Create the temporary service
echo "Creating temporary service to get NodeBalancer info..."
kubectl apply -f resources/dummy.svc.yaml

# Wait for the service to get an external IP
echo "Waiting for the temporary service to get an external IP..."
EXTERNAL_IP=""
for i in {1..30}; do
    EXTERNAL_IP=$(kubectl get svc dummy-nodebalancer -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    if [ -n "$EXTERNAL_IP" ]; then
        break
    fi
    echo "  Attempt $i: External IP not assigned yet. Retrying in 5 seconds..."
    sleep 5
done

# Get the NodeBalancer id
NB_ID=$(linode-cli nodebalancers list --json | jq -r ".[] | select(.ipv4 == \"$EXTERNAL_IP\") | .id")

if [ -z "$EXTERNAL_IP" ] || [ -z "$NB_ID" ]; then
    echo "Error: Failed to retrieve External IP or NodeBalancer ID."
    exit 1
fi

echo "Temporary service assigned External IP: $EXTERNAL_IP"
echo "NodeBalancer ID: $NB_ID"

# Clean up the temporary service
echo "Cleaning up temporary service..."
kubectl delete -f resources/dummy.svc.yaml
echo "Done."
