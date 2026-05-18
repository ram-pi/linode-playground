#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")" || exit 1

echo "========================================="
echo "Linode MoE Demo - Shutdown"
echo "========================================="

read -r -p "Destroy all resources for linode_MoE? (yes/no): " CONFIRM
if [[ "${CONFIRM}" != "yes" ]]; then
  echo "Aborted."
  exit 0
fi

if ! command -v tofu >/dev/null 2>&1; then
  echo "Error: OpenTofu (tofu) is not installed."
  exit 1
fi

echo "Destroying infrastructure..."
tofu destroy -auto-approve

echo "Cleaning local IaC artifacts..."
rm -rf .terraform .tofu
rm -f .terraform.lock.hcl .tofu.lock.hcl terraform.tfstate terraform.tfstate.backup

echo "Done."
