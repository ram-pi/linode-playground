#!/usr/bin/env bash
# start.sh — Provision an LKE Standard cluster for the Karpenter provider demo.
#
# Provisions:
#   - LKE Standard cluster in gb-lon
#   - 3 worker nodes of type g6-standard-2
#   - HA control plane with API ACL
#   - Local kubeconfig.yaml
#
# After running, follow MANUAL_DEPLOYMENT.md to install:
#   - Linode Cloud Firewall Controller
#   - Linode Karpenter Provider
#   - NodePool and scale-up/down workload
#
# Prerequisites:
#   - LINODE_TOKEN environment variable set
#   - tofu, kubectl, helm installed
#
# Usage:
#   export LINODE_TOKEN="your-linode-api-token"
#   ./start.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Color helpers ──────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"; }
ok()   { printf "${GREEN}✓ %s${NC}\n" "$*"; }
warn() { printf "${YELLOW}⚠ %s${NC}\n" "$*"; }
err()  { printf "${RED}✗ %s${NC}\n" "$*" >&2; }

# ── Pre-flight: check required CLI tools ─────────────────────────────────────
log "Pre-flight: checking required CLI tools..."

MISSING_TOOLS=()
for cmd in tofu helm kubectl; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    MISSING_TOOLS+=("${cmd}")
  fi
done

if [[ ${#MISSING_TOOLS[@]} -gt 0 ]]; then
  err "Missing required CLI tools: ${MISSING_TOOLS[*]}"
  echo ""
  echo "Install them:"
  for cmd in "${MISSING_TOOLS[@]}"; do
    case "${cmd}" in
      tofu)     echo "  brew install opentofu" ;;
      helm)     echo "  brew install helm" ;;
      kubectl)  echo "  brew install kubectl" ;;
    esac
  done
  exit 1
fi
ok "All required CLI tools found."

# ── Check LINODE_TOKEN ───────────────────────────────────────────────────────
if [[ -z "${LINODE_TOKEN:-}" ]]; then
  err "LINODE_TOKEN environment variable is not set."
  echo "  Export it before running this script:"
  echo "    export LINODE_TOKEN='your-linode-api-token'"
  exit 1
fi
ok "LINODE_TOKEN is set."

export TF_VAR_linode_token="${LINODE_TOKEN}"

# ── Step 1: OpenTofu init & apply ────────────────────────────────────────────
echo ""
echo "========================================="
log "Step 1/4: Provisioning LKE cluster with OpenTofu"
echo "========================================="

cd "${SCRIPT_DIR}"

log "Running tofu init..."
tofu init

log "Running tofu plan..."
tofu plan

log "Running tofu apply..."
tofu apply -auto-approve

# ── Step 2: Extract kubeconfig ───────────────────────────────────────────────
echo ""
echo "========================================="
log "Step 2/4: Extracting kubeconfig"
echo "========================================="

export KUBECONFIG="${SCRIPT_DIR}/kubeconfig.yaml"

if [[ ! -f "${KUBECONFIG}" ]]; then
  err "kubeconfig.yaml not found after tofu apply."
  exit 1
fi
chmod 600 "${KUBECONFIG}"
ok "Kubeconfig saved to: ${KUBECONFIG}"

# ── Step 3: Wait for cluster readiness ───────────────────────────────────────
echo ""
echo "========================================="
log "Step 3/4: Waiting for cluster to be ready"
echo "========================================="

READY="false"
log "Using KUBECONFIG: ${KUBECONFIG}"
for i in $(seq 1 60); do
  if kubectl cluster-info --request-timeout=5s &>/dev/null && \
     kubectl get nodes --request-timeout=5s &>/dev/null; then
    ok "Cluster is ready!"
    READY="true"
    break
  fi
  log "Attempt ${i}/60: Waiting for cluster..."
  sleep 10
done

if [[ "${READY}" == "false" ]]; then
  err "Cluster did not become ready within 10 minutes."
  echo "  Check the cluster status in the Linode Cloud Manager."
  echo "  Kubeconfig: ${KUBECONFIG}"
  exit 1
fi

log "Nodes:"
kubectl get nodes -o wide

# ── Step 4: Summary ──────────────────────────────────────────────────────────
echo ""
echo "========================================="
ok "LKE cluster provisioned successfully!"
echo "========================================="
echo ""

CLUSTER_ID="$(tofu output -raw cluster_id 2>/dev/null || echo '?')"
CLUSTER_LABEL="$(tofu output -raw cluster_label 2>/dev/null || echo '?')"

echo "Cluster details:"
echo "  Cluster ID    : ${CLUSTER_ID}"
echo "  Cluster Label : ${CLUSTER_LABEL}"
echo "  Region        : gb-lon"
echo "  Node Type     : g6-standard-2"
echo "  Node Count    : 3"
echo "  Kubeconfig    : ${KUBECONFIG}"
echo ""
echo "Next steps — set your KUBECONFIG and follow the manual runbook:"
echo "  export KUBECONFIG=\"${KUBECONFIG}\""
echo "  cat MANUAL_DEPLOYMENT.md"
echo ""
echo "Quick verification:"
echo "  kubectl get nodes -o wide"
echo "  kubectl cluster-info"
