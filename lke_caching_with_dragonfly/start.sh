#!/usr/bin/env bash
# start.sh — End-to-end bootstrap for the Dragonfly caching LKE demo.
#
# Provisions the LKE Standard cluster via OpenTofu, then installs:
#   1. Linode Cloud Firewall Controller (CRD + controller)
#   2. Dragonfly with dfinit + proxyAllRegistries: true
#
# After the first Dragonfly install (restartContainerRuntime: true), the script
# patches restartContainerRuntime to false for future upgrades.
#
# Prerequisites:
#   - LINODE_TOKEN environment variable set
#   - tofu, helm, kubectl installed
#
# Usage:
#   export LINODE_TOKEN="your-linode-api-token"
#   ./start.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Color helpers ────────────────────────────────────────────────────────────
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
log "Step 1/5: Provisioning LKE cluster with OpenTofu"
echo "========================================="

cd "${SCRIPT_DIR}"

log "Running tofu init..."
tofu init

log "Running tofu apply..."
tofu apply -auto-approve

# ── Step 2: Extract kubeconfig ───────────────────────────────────────────────
echo ""
echo "========================================="
log "Step 2/5: Extracting kubeconfig"
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
log "Step 3/5: Waiting for cluster to be ready"
echo "========================================="

READY="false"
log "Using KUBECONFIG: ${KUBECONFIG}"
for i in $(seq 1 60); do
  if kubectl cluster-info --request-timeout=5s &>/dev/null && kubectl get nodes --request-timeout=5s &>/dev/null; then
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

# ── Step 4: Install Cloud Firewall Controller ────────────────────────────────
echo ""
echo "========================================="
log "Step 4/5: Installing Cloud Firewall Controller"
echo "========================================="

bash "${SCRIPT_DIR}/scripts/install-cloud-firewall.sh"

# ── Step 5: Install Dragonfly ────────────────────────────────────────────────
echo ""
echo "========================================="
log "Step 5/5: Installing Dragonfly with dfinit"
echo "========================================="

bash "${SCRIPT_DIR}/scripts/install-dragonfly.sh"

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "========================================="
ok "Bootstrap complete!"
echo "========================================="
echo ""
echo "Cluster details:"
CLUSTER_ID="$(tofu output -raw cluster_id 2>/dev/null || echo '?')"
CLUSTER_LABEL="$(tofu output -raw cluster_label 2>/dev/null || echo '?')"
echo "  Cluster ID    : ${CLUSTER_ID}"
echo "  Cluster Label : ${CLUSTER_LABEL}"
echo "  Kubeconfig    : ${KUBECONFIG}"
echo ""
echo "To troubleshoot the cluster, set your KUBECONFIG:"
echo "  export KUBECONFIG=\"${KUBECONFIG}\""
echo ""
echo "Verify components:"
echo "  kubectl get nodes -o wide"
echo "  kubectl -n kube-system get pods | grep cloud-firewall"
echo "  kubectl -n dragonfly-system get pods -o wide"
echo ""
echo "Validate Dragonfly mirror on a node:"
echo "  kubectl debug node/\$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}') -- cat /etc/containerd/certs.d/_default/hosts.toml"
echo ""
echo "Open Dragonfly Manager web UI:"
echo "  kubectl -n dragonfly-system port-forward svc/dragonfly-manager 8080:8080"
echo "  Then open: http://localhost:8080"
echo ""
echo "  Default login credentials (seeded by the chart):"
echo "    Username: root"
echo "    Password: dragonfly"
echo ""
echo "  The console shows peers, schedulers, seed clients, and task stats."
echo "  WARNING: these are well-known defaults. Change the root password via"
echo "  the UI (User Profile) before exposing the manager beyond port-forward."
echo "  Also rotate the JWT signing key (auth.jwt.key) for production."
echo "  Tip: add '-n dragonfly-system get svc' first to confirm the service name."
echo ""
echo "Next steps — Validation:"
echo "  1. Image pull benchmark (cold vs hot):"
echo "     ./scripts/benchmark-image-pull.sh"
echo "     Or see MANUAL_IMAGE_PULL_TEST.md for a manual step-by-step guide."
echo ""
echo "  2. Model volume (native ImageVolume, k8s 1.35+):"
echo "     See MANUAL_MODEL_VOLUME_TEST.md for a cold vs hot P2P benchmark."
echo "     Note: only works with standard OCI images, not Docker Hub ai/* model images."
echo ""
echo "  3. Model CSI driver (Docker Hub ai/* model images):"
echo "     See MANUAL_MODEL_CSI_TEST.md for install + cold vs hot P2P benchmark."
