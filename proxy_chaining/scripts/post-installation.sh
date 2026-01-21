#!/usr/bin/env bash

# example of how to use a post-installation script
# ./post-installation.sh <LINODE_API_TOKEN> <DOMAIN_NAME>

# This script runs after the main installation process.
set -e

show_help() {
  cat << EOF
Post-installation script

Usage:
  ./post-installation.sh <LINODE_API_TOKEN> <DOMAIN_NAME>

Options:
  -h, --help    Show this help message.

EOF
}

if [[ "$1" == "-h" || "$1" == "--help" || $# -lt 2 ]]; then
  show_help
  exit 0
fi

# Take LINODE_API_TOKEN from args
LINODE_API_TOKEN=$1
DOMAIN_NAME=$2

# Change the current directory to the parent directory of the script
cd "$(dirname "$0")/.."

# Install nginx backed
echo "Deploying nginx web server..."
kubectl apply -f configs/web-server.yaml

# Create namespace for ExternalDNS
echo "Creating namespace for ExternalDNS..."
kubectl create namespace external-dns || true

# Create the secret with the Linode API token for ExternalDNS
echo "Creating Linode API token secret for ExternalDNS..."
kubectl create secret generic linode-api-token \
  --namespace external-dns \
  --from-literal=token=${LINODE_API_TOKEN} || true

# helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/
helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/
helm repo update

# Install ExternalDNS with Helm
echo "Installing ExternalDNS..."
helm upgrade --install external-dns external-dns/external-dns \
  --namespace external-dns \
  --set provider.name=linode \
  --set "sources[0]=service" \
  --set "sources[1]=ingress" \
  --set "sources[2]=gateway-httproute" \
  --set txtOwnerId=lke-cluster \
  --set policy=sync \
  --set "env[0].name=LINODE_TOKEN" \
  --set "env[0].valueFrom.secretKeyRef.name=linode-api-token" \
  --set "env[0].valueFrom.secretKeyRef.key=token"

# Check the configuration
echo "Verifying ExternalDNS configuration..."
kubectl get deploy -n external-dns external-dns -o yaml | grep -A10 "args:"

# Install cert-manager
helm repo add jetstack https://charts.jetstack.io
helm repo update

echo "Installing cert-manager..."
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true \
  --set config.kind="ControllerConfiguration" \
  --set config.enableGatewayAPI=true

# Install cert-manager webhook for Linode
kubectl create secret generic linode-credentials \
  --namespace=cert-manager \
  --from-literal=token=${LINODE_API_TOKEN} || true
helm install cert-manager-webhook-linode \
  --namespace cert-manager \
  https://github.com/linode/cert-manager-webhook-linode/releases/download/v0.3.0/cert-manager-webhook-linode-v0.3.0.tgz

# Create ClusterIssuer for cert-manager
echo "Creating ClusterIssuer for cert-manager..."
kubectl apply -f configs/cluster-issuer.yaml

# Install envoy gateway
echo "Installing Envoy Gateway..."
helm upgrade --install envoy-gateway oci://docker.io/envoyproxy/gateway-helm \
  --namespace envoy-gateway-system \
  --create-namespace \
  -f configs/envoy-gateway.values.yaml

# Create the Gateway and HTTPRoute resources
DOMAIN="${DOMAIN_NAME}"
DOMAIN_CERT_NAME="${DOMAIN_NAME//./-}"
echo "DOMAIN=\"${DOMAIN}\" DOMAIN_CERT_NAME=\"${DOMAIN_CERT_NAME}\" envsubst < configs/gateway.yaml | kubectl apply -f -"

# Retrieve Bucket endpoint for backend service from tofu output (strip protocol and path)
RAW_STATIC_URL="$(tofu output -raw static_website_url)"
OBJECT_STORAGE_EXTERNAL_NAME="${RAW_STATIC_URL#*://}"
OBJECT_STORAGE_EXTERNAL_NAME="${OBJECT_STORAGE_EXTERNAL_NAME%%/*}"
echo "DOMAIN=\"${DOMAIN}\" DOMAIN_CERT_NAME=\"${DOMAIN_CERT_NAME}\" OBJECT_STORAGE_EXTERNAL_NAME=\"${OBJECT_STORAGE_EXTERNAL_NAME}\" envsubst < configs/httproute.api.yaml | kubectl apply -f -"
echo "DOMAIN=\"${DOMAIN}\" DOMAIN_CERT_NAME=\"${DOMAIN_CERT_NAME}\" OBJECT_STORAGE_EXTERNAL_NAME=\"${OBJECT_STORAGE_EXTERNAL_NAME}\" envsubst < configs/httproute.static.yaml | kubectl apply -f -"

# You can add any additional setup or configuration commands here.
echo "Post-installation script executed."
