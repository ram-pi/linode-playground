#!/usr/bin/env bash

set -euo pipefail

cd "$(dirname "$0")" || exit 1

echo "========================================="
echo "Linode MoE Demo - Start"
echo "========================================="

if ! command -v tofu >/dev/null 2>&1; then
  echo "Error: OpenTofu (tofu) is not installed."
  echo "Install: https://opentofu.org/docs/intro/install/"
  exit 1
fi

if [[ -z "${LINODE_TOKEN:-}" ]]; then
  echo "Error: LINODE_TOKEN is not set in your environment."
  echo "Example: export LINODE_TOKEN='your-token'"
  exit 1
fi

echo "Running tofu init..."
tofu init

echo "Running tofu plan..."
tofu plan

echo "Applying infrastructure..."
tofu apply -auto-approve

echo
echo "========================================="
echo "Provisioning complete"
echo "========================================="
echo
echo "Instance type:"
tofu output -raw instance_type
echo
echo "SSH command:"
tofu output -raw ssh_command
echo
echo "After SSH, monitor cloud-init:"
tofu output -raw cloud_init_log_command
echo
echo "When cloud-init completes, continue with MANUAL_DEPLOYMENT.md"
