#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUBE1="${SCRIPT_DIR}/kubeconfig-cluster-01"
KUBE2="${SCRIPT_DIR}/kubeconfig-cluster-02"
TOKEN_FILE="${SCRIPT_DIR}/cluster-01-token.yaml"
NAMESPACE="private"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing required command: $1" >&2; exit 1; }
}

need_cmd kubectl
need_cmd skupper

for cfg in "$KUBE1" "$KUBE2"; do
  if [[ ! -f "$cfg" ]]; then
    echo "Kubeconfig not found: $cfg" >&2
    exit 1
  fi
done

echo "Creating resources on both clusters..."
kubectl apply -f "${SCRIPT_DIR}/config/cluster-01.yaml" --kubeconfig "$KUBE1"
kubectl apply -f "${SCRIPT_DIR}/config/cluster-02.yaml" --kubeconfig "$KUBE2"

echo "Install Skupper CRDs on both clusters..."
kubectl apply -f https://skupper.io/v2/install.yaml --kubeconfig "$KUBE1"
kubectl apply -f https://skupper.io/v2/install.yaml --kubeconfig "$KUBE2"

echo "Initializing Skupper site on cluster-01 in namespace ${NAMESPACE}..."
skupper site create cluster-01 --enable-ha --enable-link-access --kubeconfig "$KUBE1" -n ${NAMESPACE}

echo "Creating link token from cluster-01..."
skupper token issue /tmp/cluster-01.skupper.token --kubeconfig "$KUBE1" -n ${NAMESPACE}

echo "Initializing Skupper site on cluster-02 in namespace ${NAMESPACE}..."
skupper site create cluster-02 --enable-ha --kubeconfig "$KUBE2" -n ${NAMESPACE}

echo "Linking cluster-02 to cluster-01..."
skupper token redeem /tmp/cluster-01.skupper.token --kubeconfig "$KUBE2" -n ${NAMESPACE}

echo "Skupper status (cluster-01):"
skupper site status --kubeconfig "$KUBE1" --namespace "$NAMESPACE"
skupper link status --kubeconfig "$KUBE1" --namespace "$NAMESPACE"

echo "Skupper status (cluster-02):"
skupper site status --kubeconfig "$KUBE2" --namespace "$NAMESPACE"
skupper link status --kubeconfig "$KUBE2" --namespace "$NAMESPACE"

echo "Skupper create listeners on cluster-01..."
skupper listener create podinfo 9898 --kubeconfig "$KUBE1" -n ${NAMESPACE}

echo "Skupper create connectors on cluster-02..."
skupper connector create podinfo 9898 --kubeconfig "$KUBE2" -n ${NAMESPACE}

echo "Install skupper console on cluster-01 (optional)..."
helm install skupper-network-observer oci://quay.io/skupper/helm/network-observer --version 2.1.3 \
  --kubeconfig "$KUBE1" --namespace "$NAMESPACE"
echo "Skupper console installed on cluster-01."
echo "Use port-forwarding to access it."

echo "Done. Token saved at ${TOKEN_FILE}; remove it if no longer needed."
echo "Testing podinfo access from curl pod on cluster-01..."
CURL_POD="$(kubectl --kubeconfig "$KUBE1" -n "$NAMESPACE" get pods -l app=curl -o jsonpath='{.items[0].metadata.name}')"
if [[ -z "$CURL_POD" ]]; then
    echo "Unable to find curl pod in namespace ${NAMESPACE} on cluster-01." >&2
    exit 1
fi
kubectl --kubeconfig "$KUBE1" -n "$NAMESPACE" exec "$CURL_POD" -- curl -fsS http://podinfo:9898
