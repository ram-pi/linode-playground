#!/usr/bin/env bash
#
# gc-orphaned-pools.sh — clean up LKE NodePools orphaned by the Karpenter
# provider's failed-create path.
#
# Root cause (see TROUBLESHOOTING_STATUS.md): when the Linode LKE backend
# occasionally fails to assign an instance_id to a newly created NodePool
# (a transient backend issue, not tied to tags/taints/API version), Karpenter
# waits out `settings.lkeCreateDeadline` and then deletes the Kubernetes
# NodeClaim object — but it never calls the Linode API to delete the
# underlying NodePool. That pool is left behind forever with
# instance_id: null / status: not_ready.
#
# This script finds pools tagged `karpenter.sh/nodeclaim:<name>` whose node
# still has no instance_id AND whose NodeClaim no longer exists in the
# cluster (i.e. Karpenter has already abandoned it), and deletes them.
#
# Usage:
#   ./scripts/gc-orphaned-pools.sh <lke-cluster-id> [--yes]
#
# Requires: linode-cli (configured), kubectl (KUBECONFIG set), jq.

set -euo pipefail

CLUSTER_ID="${1:?Usage: $0 <lke-cluster-id> [--yes]}"
AUTO_YES="${2:-}"

for bin in linode-cli kubectl jq; do
  command -v "${bin}" >/dev/null 2>&1 || {
    echo "Required tool not found: ${bin}" >&2
    exit 1
  }
done

echo "Scanning LKE cluster ${CLUSTER_ID} for orphaned Karpenter NodePools..."

pools_json="$(linode-cli lke pools-list "${CLUSTER_ID}" --json)"
candidates="$(echo "${pools_json}" | jq -c '
  .[]
  | select(any(.tags[]?; startswith("karpenter.sh/nodeclaim:")))
  | select((.nodes[0].instance_id // null) == null)
')"

if [[ -z "${candidates}" ]]; then
  echo "No candidate pools (stuck + Karpenter-tagged) found."
  exit 0
fi

found_orphan=0

while IFS= read -r pool; do
  [[ -z "${pool}" ]] && continue
  pool_id="$(echo "${pool}" | jq -r '.id')"
  nodeclaim_name="$(echo "${pool}" | jq -r '.tags[] | select(startswith("karpenter.sh/nodeclaim:"))' | head -1 | cut -d: -f2)"

  if kubectl get nodeclaim "${nodeclaim_name}" >/dev/null 2>&1; then
    echo "Pool ${pool_id}: NodeClaim ${nodeclaim_name} still exists and is still being retried by Karpenter — skipping (not orphaned yet)."
    continue
  fi

  found_orphan=1
  echo ""
  echo "Orphaned pool detected:"
  echo "  pool id:    ${pool_id}"
  echo "  nodeclaim:  ${nodeclaim_name} (no longer in cluster)"
  echo "  instance_id: null (node never provisioned)"

  if [[ "${AUTO_YES}" == "--yes" || "${AUTO_YES}" == "-y" ]]; then
    reply="y"
  else
    read -r -p "Delete pool ${pool_id}? [y/N] " reply
  fi

  if [[ "${reply}" =~ ^[Yy]$ ]]; then
    linode-cli lke pool-delete "${CLUSTER_ID}" "${pool_id}"
    echo "Deleted pool ${pool_id}."
  else
    echo "Skipped pool ${pool_id}."
  fi
done <<< "${candidates}"

if [[ "${found_orphan}" -eq 0 ]]; then
  echo "All stuck pools found still have an active, retrying NodeClaim. Nothing to clean up yet."
fi
