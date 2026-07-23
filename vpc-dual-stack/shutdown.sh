#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

echo "========================================="
echo "Shutting Down VPC Dual Stack Demo"
echo "========================================="

read -r -p "Are you sure you want to destroy all resources? (yes/no): " confirm
if [ "${confirm}" != "yes" ]; then
  echo "Cancelled."
  exit 0
fi

tofu destroy -auto-approve

rm -rf .terraform .terraform.lock.hcl .tofu .tofu.lock.hcl terraform.tfstate terraform.tfstate.backup
rm -f /tmp/id_rsa-vpc-dual-stack-* \
      "$TMPDIR"/id_rsa-vpc-dual-stack-* 2>/dev/null || true

echo "Cleanup complete."
