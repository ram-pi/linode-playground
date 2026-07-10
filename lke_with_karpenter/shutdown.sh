#!/usr/bin/env bash
# shutdown.sh — Destroy the LKE cluster and clean up local files.
#
# Prerequisites:
#   - LINODE_TOKEN environment variable set
#   - tofu installed
#
# Usage:
#   export LINODE_TOKEN="your-linode-api-token"
#   ./shutdown.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Color helpers ──────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"; }
ok()   { printf "${GREEN}✓ %s${NC}\n" "$*"; }
warn() { printf "${YELLOW}⚠ %s${NC}\n" "$*"; }
err()  { printf "${RED}✗ %s${NC}\n" "$*" >&2; }

# ── Pre-flight checks ─────────────────────────────────────────────────────────
if [[ -z "${LINODE_TOKEN:-}" ]]; then
  err "LINODE_TOKEN environment variable is not set."
  echo "  Export it before running this script:"
  echo "    export LINODE_TOKEN='your-linode-api-token'"
  exit 1
fi

if ! command -v tofu >/dev/null 2>&1; then
  err "tofu (OpenTofu) is not installed."
  echo "  Install with: brew install opentofu"
  exit 1
fi

# ── Confirm destructive action ──────────────────────────────────────────────
echo ""
echo "WARNING: This will permanently destroy the LKE cluster and all resources"
echo "managed by this demo. This action is irreversible."
echo ""
read -p "Are you sure you want to continue? (yes/no): " confirm

if [[ "${confirm}" != "yes" ]]; then
  warn "Shutdown cancelled."
  exit 0
fi

export TF_VAR_linode_token="${LINODE_TOKEN}"

cd "${SCRIPT_DIR}"

echo ""
echo "========================================="
log "Destroying LKE cluster and all resources"
echo "========================================="

log "Running tofu destroy..."
tofu destroy -auto-approve

# Clean up kubeconfig
if [[ -f "${SCRIPT_DIR}/kubeconfig.yaml" ]]; then
  rm -f "${SCRIPT_DIR}/kubeconfig.yaml"
  ok "Removed kubeconfig.yaml"
fi

# Clean up any terraform plan files
rm -f "${SCRIPT_DIR}/tfplan"

echo ""
ok "Shutdown complete!"
