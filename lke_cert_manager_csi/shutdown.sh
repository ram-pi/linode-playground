#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

read -r -p "Delete the LKE Enterprise cluster, cert-manager, CSI driver, and demo workloads? Type yes: " reply
if [[ "$reply" != "yes" ]]; then
  echo "Aborted."
  exit 1
fi

if [[ -f ".env.local" ]]; then
  set -a
  # shellcheck disable=SC1091
  source ".env.local"
  set +a
fi

if [[ -f "kubeconfig" ]]; then
  export KUBECONFIG="$PWD/kubeconfig"
  kubectl delete namespace cert-manager-csi-demo --ignore-not-found=true || true
fi

tofu destroy -auto-approve
