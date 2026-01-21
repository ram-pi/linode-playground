#!/usr/bin/env bash

# Uninstall script to remove all Helm charts and Kubernetes resources
# while keeping the LKE cluster intact

set -e

# Help function
show_help() {
  cat << EOF
Uninstall Script - Remove all Helm charts and Kubernetes resources

USAGE:
  ./uninstall.sh [OPTIONS]

OPTIONS:
  -h, --help      Show this help message
  --confirm       Run uninstallation without prompting (use with caution)

DESCRIPTION:
  This script removes all deployed Helm charts and Kubernetes resources
  while preserving the LKE cluster itself. This includes:
  - Envoy Gateway
  - cert-manager
  - ExternalDNS
  - Nginx backend
  - Caddy resources and Ingress rules

  To delete the LKE cluster entirely, run: terraform destroy

EXAMPLES:
  ./uninstall.sh                    # Shows this help message
  ./uninstall.sh --confirm          # Proceeds with uninstallation

EOF
}

# Parse arguments
CONFIRM=false
for arg in "$@"; do
  case $arg in
    -h|--help)
      show_help
      exit 0
      ;;
    --confirm)
      CONFIRM=true
      ;;
    *)
      echo "Unknown option: $arg"
      show_help
      exit 1
      ;;
  esac
done

# Show help by default if no --confirm flag
if [ "$CONFIRM" = false ]; then
  show_help
  exit 0
fi

echo "Starting uninstallation process..."

# Change to the parent directory
cd "$(dirname "$0")/.."

# Delete Gateway and HTTPRoute resources
echo "Deleting Gateway and HTTPRoute resources..."
kubectl delete -f configs/httproute.yaml --ignore-not-found=true
kubectl delete -f configs/gateway.yaml --ignore-not-found=true

# Delete ClusterIssuer
echo "Deleting ClusterIssuer..."
kubectl delete -f configs/cluster-issuer.yaml --ignore-not-found=true

# Uninstall Envoy Gateway
echo "Uninstalling Envoy Gateway..."
helm uninstall envoy-gateway --namespace envoy-gateway-system || true
kubectl delete namespace envoy-gateway-system --ignore-not-found=true

# Uninstall cert-manager
echo "Uninstalling cert-manager..."
helm uninstall cert-manager --namespace cert-manager || true
kubectl delete namespace cert-manager --ignore-not-found=true

# Uninstall ExternalDNS
echo "Uninstalling ExternalDNS..."
helm uninstall external-dns --namespace external-dns || true
kubectl delete secret linode-api-token --namespace external-dns --ignore-not-found=true
kubectl delete namespace external-dns --ignore-not-found=true

# Delete nginx backend
echo "Deleting nginx backend..."
kubectl delete -f configs/web-server.yaml --ignore-not-found=true

# Optional: Delete Caddy resources if they exist
echo "Deleting certificate resources if present..."
kubectl delete -f configs/certificate.yaml --ignore-not-found=true

echo "Uninstallation complete. LKE cluster is still running."
echo "To delete the LKE cluster, run: terraform destroy"
