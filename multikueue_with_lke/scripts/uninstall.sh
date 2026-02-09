#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CONFIG_DIR="${TOP_DIR}/configs"
KUBE1="${TOP_DIR}/kubeconfig-cluster-01"
KUBE2="${TOP_DIR}/kubeconfig-cluster-02"
NAMESPACE="kueue-system"
MULTIKUEUE_VERSION="0.15.2"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing required command: $1" >&2; exit 1; }
}

need_cmd kubectl
need_cmd helm

for cfg in "$KUBE1" "$KUBE2"; do
  if [[ ! -f "$cfg" ]]; then
    echo "Kubeconfig not found: $cfg" >&2
    exit 1
  fi
done

helm uninstall kueue --namespace $NAMESPACE --kubeconfig="$KUBE1" || true
echo "✓ Kueue Control Plane uninstalled from Cluster 1"
helm uninstall kueue --namespace $NAMESPACE --kubeconfig="$KUBE2" || true
echo "✓ Kueue Worker uninstalled from Cluster 2"

kubectl -n $NAMESPACE delete secret kueue-webhook-server-cert --kubeconfig="$KUBE1" || true
echo "✓ Kueue webhook server certificate secret deleted from Cluster 1"
kubectl -n $NAMESPACE delete secret kueue-webhook-server-cert --kubeconfig="$KUBE2" || true
echo "✓ Kueue webhook server certificate secret deleted from Cluster 2"
