#!/usr/bin/env bash

set -euo pipefail

echo "========================================="
echo "Shutting Down Distributed Inference Demo"
echo "========================================="
echo ""

if [[ -z "${LINODE_TOKEN:-}" ]]; then
  echo "Error: LINODE_TOKEN environment variable is not set"
  exit 1
fi

read -r -p "Destroy all provisioned resources? (yes/no): " confirm
if [[ "${confirm}" != "yes" ]]; then
  echo "Shutdown cancelled."
  exit 0
fi

echo "Running tofu destroy..."
tofu destroy -auto-approve

echo "Cleaning local artifacts..."
rm -rf .terraform .tofu
rm -rf .karmada
rm -f .terraform.lock.hcl .tofu.lock.hcl
rm -f terraform.tfstate terraform.tfstate.backup tfplan
rm -f kubeconfig-gb-lon kubeconfig-de-fra-2 kubeconfig-us-sea

echo "Cleanup complete."
