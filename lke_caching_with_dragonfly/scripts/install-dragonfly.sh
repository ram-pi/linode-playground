#!/usr/bin/env bash
# install-dragonfly.sh — Install Dragonfly with dfinit and proxyAllRegistries.
#
# Installs Dragonfly (chart v1.7.0) with 1 manager, 1 scheduler, 1 seed client,
# and dfinit enabled with proxyAllRegistries: true so ALL registry pulls route
# through the node-local Dragonfly proxy (127.0.0.1:4001).
#
# First-install behaviour:
#   restartContainerRuntime starts as true so containerd reloads the mirror
#   config on every node. After the first successful rollout, this script
#   patches the value to false and re-runs helm upgrade to prevent future
#   containerd restarts.
#
# Prerequisites:
#   - KUBECONFIG set to the LKE cluster kubeconfig (export KUBECONFIG=./kubeconfig.yaml)
#   - helm and kubectl installed
#
# Usage:
#   export KUBECONFIG="$PWD/kubeconfig.yaml"
#   ./scripts/install-dragonfly.sh [--skip-restart-patch]
#
# Flags:
#   --skip-restart-patch   Skip patching restartContainerRuntime to false after
#                          the first install. Use this if you want to keep
#                          containerd restarts enabled.
#   -h, --help             Show this help.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DFLY_VALUES="${REPO_DIR}/configs/dragonfly/values.yaml"
DRAGONFLY_CHART_VERSION="1.7.0"
SKIP_RESTART_PATCH="false"

# ── Color helpers ────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { printf '[%s] %s\n' "$(date '+%H:%M:%S')" "$*"; }
ok()   { printf "${GREEN}✓ %s${NC}\n" "$*"; }
warn() { printf "${YELLOW}⚠ %s${NC}\n" "$*"; }
err()  { printf "${RED}✗ %s${NC}\n" "$*" >&2; }

# ── Parse args ───────────────────────────────────────────────────────────────
usage() { grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 1; }
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-restart-patch) SKIP_RESTART_PATCH="true"; shift ;;
    -h|--help) usage ;;
    *) err "Unknown option: $1"; usage ;;
  esac
done

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

# ── Helper: revert private IP patch if applied ───────────────────────────────
# The patch-dfdaemon-private-ip.sh script modifies the DaemonSet volumeMounts
# via kubectl patch, which conflicts with helm upgrade. Before any helm upgrade,
# we revert the patch so helm can apply cleanly. The patch is re-applied after.
revert_private_ip_patch() {
  if kubectl -n dragonfly-system get ds dragonfly-client -o jsonpath='{.spec.template.spec.initContainers[*].name}' 2>/dev/null | grep -q "patch-advertise-ip"; then
    log "  Reverting private IP patch (will re-apply after helm upgrade)..."
    kubectl -n dragonfly-system patch ds dragonfly-client --type=json -p='[
      {"op": "remove", "path": "/spec/template/spec/initContainers/0"},
      {"op": "replace", "path": "/spec/template/spec/containers/0/volumeMounts/0", "value": {"mountPath": "/etc/dragonfly", "name": "config"}}
    ]' 2>/dev/null || true
    # Wait for rollout to stabilize
    kubectl -n dragonfly-system rollout status ds/dragonfly-client --timeout=120s 2>/dev/null || true
    log "  Patch reverted."
  fi
}

# ── Install Dragonfly ────────────────────────────────────────────────────────
echo ""
log "Adding Dragonfly Helm repository..."
helm repo add dragonfly https://dragonflyoss.github.io/helm-charts/ 2>/dev/null || true
helm repo update dragonfly

# Revert any existing private IP patch before helm upgrade (avoids field conflict)
revert_private_ip_patch

log "Installing Dragonfly chart v${DRAGONFLY_CHART_VERSION} (restartContainerRuntime: true on first install)..."
helm upgrade --install dragonfly dragonfly/dragonfly \
  --version "${DRAGONFLY_CHART_VERSION}" \
  --namespace dragonfly-system \
  --create-namespace \
  -f "${DFLY_VALUES}" \
  --wait --timeout 10m

ok "Dragonfly installed (first install with containerd restart)."

# ── Verify components ─────────────────────────────────────────────────────────
echo ""
log "Dragonfly pods:"
kubectl -n dragonfly-system get pods -o wide

echo ""
log "Waiting for all Dragonfly pods to be ready..."
kubectl -n dragonfly-system wait \
  --for=condition=Ready pod --all \
  --timeout=5m 2>/dev/null || warn "Not all pods are Ready — check with: kubectl -n dragonfly-system get pods"
ok "Dragonfly pods are ready."

# ── Verify dfinit wrote hosts.toml on nodes ──────────────────────────────────
echo ""
log "Verifying dfinit wrote containerd mirror config on first node..."
FIRST_NODE="$(kubectl get nodes --no-headers -o custom-columns='NAME:.metadata.name' 2>/dev/null | head -n1)"

if [[ -n "${FIRST_NODE}" ]]; then
  log "  Checking node: ${FIRST_NODE}"
  kubectl run dfinit-check-"${FIRST_NODE: -5}" \
    --image=docker.io/dragonflyoss/client:v1.4.0 \
    --restart=Never \
    --overrides="{
      \"spec\": {
        \"nodeSelector\": {\"kubernetes.io/hostname\": \"${FIRST_NODE}\"},
        \"tolerations\": [{\"operator\": \"Exists\"}],
        \"hostPID\": true,
        \"containers\": [{
          \"name\": \"check\",
          \"image\": \"docker.io/dragonflyoss/client:v1.4.0\",
          \"securityContext\": {\"privileged\": true},
          \"command\": [\"nsenter\",\"--mount=/proc/1/ns/mnt\",\"--\",\"sh\",\"-c\",\"cat /etc/containerd/certs.d/_default/hosts.toml 2>/dev/null || echo NOT_FOUND\"]
        }]
      }
    }" --wait --timeout=120s 2>/dev/null || true

  LOGS="$(kubectl logs dfinit-check-"${FIRST_NODE: -5}" 2>/dev/null || true)"
  kubectl delete pod dfinit-check-"${FIRST_NODE: -5}" --ignore-not-found --timeout=30s 2>/dev/null || true

  if printf '%s' "${LOGS}" | grep -q "127.0.0.1:4001"; then
    ok "dfinit mirror config active on ${FIRST_NODE} (127.0.0.1:4001 found in _default/hosts.toml)"
  elif printf '%s' "${LOGS}" | grep -q "NOT_FOUND"; then
    warn "_default/hosts.toml not found on ${FIRST_NODE} — dfinit may still be initializing."
    echo "  Check dfinit logs: kubectl -n dragonfly-system logs ds/dragonfly-client -c dfinit"
  else
    warn "Could not verify hosts.toml on ${FIRST_NODE}."
    echo "  Manual check: kubectl debug node/${FIRST_NODE} -- cat /etc/containerd/certs.d/_default/hosts.toml"
  fi
fi

# ── Patch restartContainerRuntime to false ───────────────────────────────────
if [[ "${SKIP_RESTART_PATCH}" == "true" ]]; then
  warn "Skipping restartContainerRuntime patch (--skip-restart-patch)."
  echo "  Future helm upgrades will restart containerd on each node."
else
  echo ""
  log "Patching restartContainerRuntime: true → false for future upgrades..."

  if grep -q "restartContainerRuntime: true" "${DFLY_VALUES}"; then
    sed -i.bak 's/restartContainerRuntime: true/restartContainerRuntime: false/' "${DFLY_VALUES}"
    rm -f "${DFLY_VALUES}.bak"
    ok "Patched ${DFLY_VALUES}: restartContainerRuntime is now false."

    log "Re-running helm upgrade with patched values..."
    # Revert private IP patch before helm upgrade (avoids field conflict)
    revert_private_ip_patch
    helm upgrade --install dragonfly dragonfly/dragonfly \
      --version "${DRAGONFLY_CHART_VERSION}" \
      --namespace dragonfly-system \
      -f "${DFLY_VALUES}" \
      --wait --timeout 5m
    ok "Dragonfly upgraded — containerd will not restart on future upgrades."
  else
    log "  restartContainerRuntime is already false — no patch needed."
  fi
fi

# ── Patch dfdaemon to advertise private IP ───────────────────────────────────
# By default, dfdaemon with hostNetwork: true advertises its public IP to the
# scheduler, causing P2P traffic to go over the public internet. Patch the
# DaemonSet with an init container that injects the node's private IP.
# This is a security/isolation best practice (keeps P2P off the public internet).
# The init container is self-healing — new nodes automatically get the patch.
echo ""
log "Patching dfdaemon to advertise private IP (security best practice)..."
bash "${SCRIPT_DIR}/patch-dfdaemon-private-ip.sh"

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "========================================="
ok "Dragonfly installation complete!"
echo "========================================="
echo ""
echo "Components:"
echo "  Manager     : $(kubectl -n dragonfly-system get deploy dragonfly-manager -o jsonpath='{.spec.replicas}' 2>/dev/null || echo '?') replica(s)"
echo "  Scheduler   : $(kubectl -n dragonfly-system get deploy dragonfly-scheduler -o jsonpath='{.spec.replicas}' 2>/dev/null || echo '?') replica(s)"
echo "  Seed Client : $(kubectl -n dragonfly-system get deploy dragonfly-seed-client -o jsonpath='{.spec.replicas}' 2>/dev/null || echo '?') replica(s)"
echo "  Client DS   : $(kubectl -n dragonfly-system get ds dragonfly-client -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo '?') pod(s) (DaemonSet)"
echo ""
echo "Verify mirror config on any node:"
echo "  kubectl debug node/<node-name> -- cat /etc/containerd/certs.d/_default/hosts.toml"
echo ""
echo "Next steps:"
echo "  1. Run image pull benchmark:  ./scripts/benchmark-image-pull.sh"
echo "  2. Manual tests:              See MANUAL_IMAGE_PULL_TEST.md,"
echo "                                MANUAL_MODEL_VOLUME_TEST.md,"
echo "                                MANUAL_MODEL_CSI_TEST.md"
