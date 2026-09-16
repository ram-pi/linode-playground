#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

if [[ -f ".env.local" ]]; then
  set -a
  # shellcheck disable=SC1091
  source ".env.local"
  set +a
fi

: "${LINODE_TOKEN:?Set LINODE_TOKEN in the environment or .env.local}"

export CERT_DURATION="${CERT_DURATION:-30m}"

tofu init
tofu apply -auto-approve

export KUBECONFIG="$PWD/kubeconfig"

helm repo add jetstack https://charts.jetstack.io >/dev/null
helm repo update jetstack >/dev/null

helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --version v1.21.1 --set installCRDs=true

helm upgrade --install cert-manager-csi-driver jetstack/cert-manager-csi-driver \
  --namespace cert-manager --create-namespace \
  --version v0.16.0

echo "Waiting for cert-manager to be ready..."
kubectl -n cert-manager rollout status deployment/cert-manager --timeout=5m
kubectl -n cert-manager rollout status deployment/cert-manager-webhook --timeout=5m

echo "Waiting for cert-manager CSI driver to be ready..."
kubectl -n cert-manager rollout status daemonset/cert-manager-csi-driver --timeout=5m

kubectl apply -f configs/00-namespace.yaml
kubectl apply -f configs/10-root-ca.yaml

echo "Waiting for root CA to be issued..."
kubectl -n cert-manager wait --for=condition=Ready certificate/root-ca --timeout=5m

# Render templates with CERT_DURATION substituted.
sed "s/\${CERT_DURATION}/$CERT_DURATION/g" configs/20-node-cert-daemonset.yaml.tpl > configs/20-node-cert-daemonset.yaml
sed "s/\${CERT_DURATION}/$CERT_DURATION/g" configs/30-reader-pod.yaml.tpl > configs/30-reader-pod.yaml

kubectl apply -f configs/20-node-cert-daemonset.yaml
kubectl apply -f configs/30-reader-pod.yaml

echo "Waiting for node-cert-reader DaemonSet rollout..."
if ! kubectl -n cert-manager-csi-demo rollout status daemonset/node-cert-reader --timeout=5m; then
  echo "node-cert-reader rollout failed. Diagnostics:"
  kubectl -n cert-manager-csi-demo get pods -o wide
  kubectl -n cert-manager-csi-demo describe pod -l app=node-cert-reader
  exit 1
fi

echo "Waiting for cert-reader-pod to be ready..."
kubectl -n cert-manager-csi-demo wait --for=condition=Ready pod/cert-reader-pod --timeout=5m

echo
echo "=== Per-node certificates (DaemonSet) ==="
kubectl -n cert-manager-csi-demo logs -l app=node-cert-reader --all-containers=true --prefix=true

echo
echo "=== Reader pod certificate ==="
kubectl -n cert-manager-csi-demo logs pod/cert-reader-pod

cat > .runtime.env <<EOF
export KUBECONFIG="$PWD/kubeconfig"
export CERT_DURATION="$CERT_DURATION"
EOF

echo
echo "Infrastructure ready. Run: source .runtime.env"
echo "Inspect certs anytime with: kubectl -n cert-manager-csi-demo logs -l app=node-cert-reader"
echo
echo "Kubeconfig:"
echo "export KUBECONFIG=\"$PWD/kubeconfig\""
