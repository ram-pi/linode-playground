#!/usr/bin/env bash

# Check if KUBECONFIG is set
if [ -z "$KUBECONFIG" ]; then
    echo "Error: KUBECONFIG environment variable is not set"
    echo "Please set KUBECONFIG to point to your LKE cluster's kubeconfig file."
    exit 1
fi

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    echo "Error: helm is not installed"
    echo "Please install Helm first"
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl is not installed"
    echo "Please install kubectl first"
    exit 1
fi

# Verify cluster connectivity
if ! kubectl get nodes &> /dev/null; then
    echo "Error: Unable to connect to the Kubernetes cluster"
    echo "Please ensure your KUBECONFIG is correct and the cluster is running"
    exit 1
fi

echo "========================================="
echo "Installing Helm chart for hardening..."
echo "========================================="
echo ""
# Add the secure-lke Helm repository
helm repo add linode-cfw https://linode.github.io/cloud-firewall-controller
helm repo update linode-cfw
helm install cloud-firewall-crd linode-cfw/cloud-firewall-crd \
&& kubectl wait --for condition=established --timeout=60s crd/cloudfirewalls.networking.linode.com \
&& helm install cloud-firewall linode-cfw/cloud-firewall-controller

echo ""
echo "========================================="
echo "Helm chart for hardening installed!"
echo "For more information about the installed chart, visit: https://github.com/linode/cloud-firewall-controller"
echo ""
