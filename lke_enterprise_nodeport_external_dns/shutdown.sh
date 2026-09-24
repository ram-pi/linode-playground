#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${PROJECT_DIR}"

: "${LINODE_TOKEN:?Export LINODE_TOKEN before destroying resources.}"

read -r -p "Destroy the LKE cluster, VPC, and client VM? Type yes: " confirmation
if [[ "${confirmation}" != "yes" ]]; then
  echo "Shutdown cancelled."
  exit 0
fi

tofu init -reconfigure
tofu destroy
rm -f client_key kubeconfig-primary.yaml kubeconfig-secondary.yaml
