#!/usr/bin/env bash
set -euo pipefail

echo "======================================"
echo "DCGM Setup Script"
echo "======================================"
echo ""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
KUBE1="${TOP_DIR}/kubeconfig-cluster-01"
KUBE2="${TOP_DIR}/kubeconfig-cluster-02"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing required command: $1" >&2; exit 1; }
}

echo "Checking dependencies..."
need_cmd kubectl
echo "✓ kubectl found"
echo ""

echo "Validating kubeconfig files..."
for cfg in "$KUBE1" "$KUBE2"; do
  if [[ ! -f "$cfg" ]]; then
    echo "Kubeconfig not found: $cfg" >&2
    exit 1
  fi
  echo "✓ Found: $cfg"
done
echo ""

# Grafana dashboard setup
echo "======================================"
echo "Setting up Grafana Dashboards"
echo "======================================"
echo ""

echo "Removing existing DCGM dashboard ConfigMap (if exists)..."
echo "Removing existing DCGM dashboard ConfigMap (if exists)..."
kubectl delete configmap dcgm-dashboard -n monitoring --kubeconfig="$KUBE2" || true

echo "Creating DCGM dashboard ConfigMap..."
kubectl create configmap dcgm-dashboard \
  --from-file=${TOP_DIR}/monitoring/grafana/dcgm-dashboard.json \
  -n monitoring \
  --kubeconfig="$KUBE2" \

echo "✓ DCGM dashboard ConfigMap created"
echo ""

echo "Removing existing DCGM community dashboard ConfigMap (if exists)..."
kubectl delete configmap dcgm-dashboard-community -n monitoring --kubeconfig="$KUBE2" || true

echo "Creating DCGM community dashboard ConfigMap..."
kubectl create configmap dcgm-dashboard-community \
  --from-file=${TOP_DIR}/monitoring/grafana/dcgm-dashboard.community.json \
  -n monitoring \
  --kubeconfig="$KUBE2" \

echo "✓ DCGM community dashboard ConfigMap created"
echo ""

echo "Labeling dashboards for Grafana sidecar discovery..."
kubectl label configmap dcgm-dashboard grafana_dashboard="1" -n monitoring \
  --kubeconfig="$KUBE2"
kubectl label configmap dcgm-dashboard-community grafana_dashboard="1" -n monitoring \
  --kubeconfig="$KUBE2"
echo "✓ Dashboards labeled"
echo ""

echo "======================================"
echo "Testing GPU Nodes"
echo "======================================"
echo ""

echo "Deploying CUDA test pod to cluster-02..."
kubectl apply -f ./configs/test_cuda.pod.yaml -n default --kubeconfig="$KUBE2"
echo "✓ Test pod deployed"
echo ""

echo "======================================"
echo "Setup Complete!"
echo "======================================"
echo ""
echo "Checking pod status..."
kubectl get pods -n default --kubeconfig="$KUBE2"
