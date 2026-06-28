#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

KUBECONFIG_PATH="${REPO_DIR}/kubeconfig.yaml"
DELETE_DATA="false"
YES="false"
KEEP_CERT_MANAGER="false"
KEEP_ENVOY="false"

HARBOR_NAMESPACE="harbor"
ENVOY_NAMESPACE="envoy-gateway-system"
CERT_MANAGER_NAMESPACE="cert-manager"
ENV_FILE="${REPO_DIR}/.harbor.env"

usage() {
  cat <<'EOF'
Usage:
  scripts/uninstall-harbor-envoy.sh [options]

Options:
  --kubeconfig PATH      Optional. Defaults to ./kubeconfig.yaml.
  --delete-data          Delete Harbor PVCs/PVs and .harbor.env.
  --yes                  Skip destructive confirmation prompt.
  --keep-cert-manager    Do not uninstall cert-manager.
  --keep-envoy           Do not uninstall Envoy Gateway.
  -h, --help             Show this help.

Default behavior removes Harbor/Envoy resources but keeps Harbor data PVCs and
.harbor.env. Use --delete-data only for a full reset.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --kubeconfig)
      if [[ $# -lt 2 || "${2:-}" == --* ]]; then
        printf 'Missing value for --kubeconfig.\n' >&2
        exit 1
      fi
      KUBECONFIG_PATH="${2:-}"
      shift 2
      ;;
    --delete-data)
      DELETE_DATA="true"
      shift
      ;;
    --yes)
      YES="true"
      shift
      ;;
    --keep-cert-manager)
      KEEP_CERT_MANAGER="true"
      shift
      ;;
    --keep-envoy)
      KEEP_ENVOY="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n\n' "$1" >&2
      usage
      exit 1
      ;;
  esac
done

for cmd in kubectl helm; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    printf 'Required command not found: %s\n' "${cmd}" >&2
    exit 1
  fi
done

if [[ ! -f "${KUBECONFIG_PATH}" ]]; then
  printf 'Kubeconfig not found: %s\n' "${KUBECONFIG_PATH}" >&2
  exit 1
fi

export KUBECONFIG="${KUBECONFIG_PATH}"

if [[ "${DELETE_DATA}" == "true" && "${YES}" != "true" ]]; then
  cat <<'EOF'
This will delete Harbor database, registry storage, job logs, Redis data,
Trivy data, and local .harbor.env state.

Type DELETE to continue:
EOF
  read -r confirmation
  if [[ "${confirmation}" != "DELETE" ]]; then
    printf 'Aborted.\n'
    exit 1
  fi
fi

printf 'Uninstalling Harbor release if present...\n'
helm uninstall harbor --namespace "${HARBOR_NAMESPACE}" >/dev/null 2>&1 || true

printf 'Deleting Harbor Gateway API and certificate resources...\n'
kubectl -n "${HARBOR_NAMESPACE}" delete httproute harbor --ignore-not-found=true
kubectl -n "${HARBOR_NAMESPACE}" delete certificate harbor-tls --ignore-not-found=true
kubectl -n "${HARBOR_NAMESPACE}" delete gateway harbor-gateway --ignore-not-found=true
kubectl delete clusterissuer letsencrypt-harbor --ignore-not-found=true

if [[ "${DELETE_DATA}" == "true" ]]; then
  printf 'Deleting Harbor PVCs...\n'
  mapfile -t harbor_pvs < <(kubectl -n "${HARBOR_NAMESPACE}" get pvc -o jsonpath='{range .items[*]}{.spec.volumeName}{"\n"}{end}' 2>/dev/null || true)
  kubectl -n "${HARBOR_NAMESPACE}" delete pvc --all --ignore-not-found=true

  for pv in "${harbor_pvs[@]}"; do
    if [[ -n "${pv}" ]]; then
      kubectl delete pv "${pv}" --ignore-not-found=true
    fi
  done

  rm -f "${ENV_FILE}"
fi

printf 'Deleting Harbor namespace if empty...\n'
if kubectl get namespace "${HARBOR_NAMESPACE}" >/dev/null 2>&1; then
  if [[ -z "$(kubectl -n "${HARBOR_NAMESPACE}" get all,pvc,secret,configmap,certificate,httproute,gateway --ignore-not-found -o name 2>/dev/null || true)" ]]; then
    kubectl delete namespace "${HARBOR_NAMESPACE}" --ignore-not-found=true
  else
    printf 'Harbor namespace retained because resources still exist.\n'
  fi
fi

if [[ "${KEEP_CERT_MANAGER}" != "true" ]]; then
  printf 'Uninstalling cert-manager...\n'
  helm uninstall cert-manager --namespace "${CERT_MANAGER_NAMESPACE}" >/dev/null 2>&1 || true
  kubectl delete namespace "${CERT_MANAGER_NAMESPACE}" --ignore-not-found=true
fi

if [[ "${KEEP_ENVOY}" != "true" ]]; then
  printf 'Uninstalling Envoy Gateway...\n'
  helm uninstall eg --namespace "${ENVOY_NAMESPACE}" >/dev/null 2>&1 || true
  kubectl delete gatewayclass eg --ignore-not-found=true
  kubectl delete namespace "${ENVOY_NAMESPACE}" --ignore-not-found=true
fi

cat <<EOF

Harbor Envoy approach uninstall complete.

Data deleted: ${DELETE_DATA}
cert-manager kept: ${KEEP_CERT_MANAGER}
Envoy Gateway kept: ${KEEP_ENVOY}
EOF
