#!/usr/bin/env bash
# install-cloud-firewall.sh — Install Linode Cloud Firewall Controller CRD + controller.
#
# This is a PoC install: the controller is deployed to validate it runs and
# reconciles on LKE Standard. No CloudFirewall CR is applied.
#
# Prerequisites:
#   - KUBECONFIG set to the LKE cluster kubeconfig (export KUBECONFIG=./kubeconfig.yaml)
#   - helm and kubectl installed
#
# Usage:
#   export KUBECONFIG="$PWD/kubeconfig.yaml"
#   ./scripts/install-cloud-firewall.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
CFW_VALUES="${REPO_DIR}/configs/cloud-firewall/values.yaml"

# ── Color helpers ────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"; }
ok()   { printf "${GREEN}✓ %s${NC}\n" "$*"; }
warn() { printf "${YELLOW}⚠ %s${NC}\n" "$*"; }
err()  { printf "${RED}✗ %s${NC}\n" "$*" >&2; }

# ── Pre-flight checks ────────────────────────────────────────────────────────
log "Pre-flight checks..."

if [[ -z "${KUBECONFIG:-}" ]]; then
  err "KUBECONFIG is not set."
  echo "  Export it before running this script:"
  echo "    export KUBECONFIG=\"${REPO_DIR}/kubeconfig.yaml\""
  exit 1
fi

if [[ ! -f "${KUBECONFIG}" ]]; then
  err "Kubeconfig file not found: ${KUBECONFIG}"
  exit 1
fi

for cmd in helm kubectl; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    err "Required command not found: ${cmd}"
    echo "  Install it with: brew install ${cmd}"
    exit 1
  fi
done

if ! kubectl get nodes >/dev/null 2>&1; then
  err "Cannot connect to the cluster. Check KUBECONFIG: ${KUBECONFIG}"
  exit 1
fi

ok "Pre-flight passed."

# ── Install CRD ───────────────────────────────────────────────────────────────
echo ""
log "Adding Linode Cloud Firewall Helm repository..."
helm repo add linode-cfw https://linode.github.io/cloud-firewall-controller 2>/dev/null || true
helm repo update linode-cfw

log "Installing CloudFirewall CRD (v0.2.0)..."
helm upgrade --install cloud-firewall-crd \
  linode-cfw/cloud-firewall-crd \
  --version 0.2.0 \
  --namespace kube-system \
  --wait --timeout 2m

log "Waiting for CloudFirewall CRD to be established..."
kubectl wait --for condition=established --timeout=60s \
  crd/cloudfirewalls.networking.linode.com
ok "CloudFirewall CRD established."

# ── Install Controller ────────────────────────────────────────────────────────
log "Installing Cloud Firewall Controller (v0.2.1)..."
helm upgrade --install cloud-firewall \
  linode-cfw/cloud-firewall-controller \
  --version 0.2.1 \
  --namespace kube-system \
  -f "${CFW_VALUES}" \
  --wait --timeout 5m

ok "Cloud Firewall Controller installed."

# ── Verify ────────────────────────────────────────────────────────────────────
echo ""
log "Verifying controller pod..."
kubectl -n kube-system get pods -l app.kubernetes.io/name=cloud-firewall-controller -o wide || \
  kubectl -n kube-system get pods | grep cloud-firewall || true

echo ""
ok "Cloud Firewall Controller installation complete."
echo ""

# ── Apply CloudFirewall CR with Dragonfly P2P rules ──────────────────────────
log "Applying CloudFirewall CR with Dragonfly P2P inbound rules..."
log "  (Without these rules, inbound_policy: DROP blocks dfdaemon P2P traffic"
log "   between nodes, making hot P2P pulls fall back to back-to-source.)"
echo ""
log "  Using 192.168.128.0/17 (Linode private network) as the source CIDR."
log "  This covers all current and future nodes — the Cloud Firewall Controller"
log "  auto-registers new nodes as firewall devices, and new nodes get private"
log "  IPs in this range automatically. No re-run needed when scaling."
echo ""
log "  NOTE: This assumes the private IP patch is applied (install-dragonfly.sh"
log "  applies it automatically). If you skip the patch, dfdaemon advertises its"
log "  public IP and you must manually add each node's external IP as a /32 rule:"
log "    kubectl -n kube-system patch cloudfirewall primary --type=json -p='[...]'"

# Generate the CloudFirewall CR with the private network CIDR only.
# The 192.168.128.0/17 CIDR covers all Linode private IPs, including new nodes.
CFW_CR="${REPO_DIR}/configs/cloud-firewall/cloudfirewall-cr.yaml"
cat > "${CFW_CR}" << 'CR_EOF'
apiVersion: networking.linode.com/alpha1v1
kind: CloudFirewall
metadata:
  name: primary
  namespace: kube-system
spec:
  defaultRules: true
  ruleset:
    inbound_policy: DROP
    outbound_policy: ACCEPT
    inbound:
      - label: allow-dragonfly-p2p-tcp
        action: ACCEPT
        protocol: TCP
        ports: "4000,4002,4005"
        addresses:
          ipv4:
            - "192.168.128.0/17"
        description: "Dragonfly P2P dfdaemon upload/download ports (intra-cluster private)"
      - label: allow-dragonfly-p2p-udp
        action: ACCEPT
        protocol: UDP
        ports: "4006"
        addresses:
          ipv4:
            - "192.168.128.0/17"
        description: "Dragonfly P2P dfdaemon QUIC port (intra-cluster private)"
CR_EOF

kubectl apply -f "${CFW_CR}"
ok "CloudFirewall CR applied — Dragonfly P2P ports open for 192.168.128.0/17."
echo ""
echo "For more information: https://github.com/linode/cloud-firewall-controller"
