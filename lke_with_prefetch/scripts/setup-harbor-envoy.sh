#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

KUBECONFIG_PATH="${REPO_DIR}/kubeconfig.yaml"
LETSENCRYPT_STAGING="false"
LETSENCRYPT_EMAIL=""
HARBOR_ADMIN_PASSWORD=""

ENV_FILE="${REPO_DIR}/.harbor.env"
HARBOR_NAMESPACE="harbor"
ENVOY_NAMESPACE="envoy-gateway-system"
CERT_MANAGER_NAMESPACE="cert-manager"
HARBOR_RELEASE="harbor"
HARBOR_CHART_VERSION="1.19.1"
CERT_MANAGER_CHART_VERSION="v1.20.0"
ENVOY_GATEWAY_CHART_VERSION="v1.8.0"
HARBOR_SECRET_NAME="harbor-tls"
HARBOR_OVERRIDE_FILE=""

usage() {
  cat <<'EOF'
Usage:
  scripts/setup-harbor-envoy.sh --email you@example.com --admin-password '<password>' [options]

Options:
  --email EMAIL             Required. Let's Encrypt ACME account email.
  --admin-password PASSWORD Required. Harbor admin password.
  --kubeconfig PATH         Optional. Defaults to ./kubeconfig.yaml.
  --letsencrypt-staging     Optional. Use Let's Encrypt staging endpoint.
  -h, --help                Show this help.

The email is required by cert-manager for the Let's Encrypt ACME account.
Let's Encrypt uses it for account registration, expiry notices, and
rate-limit/abuse contact. It is not used by Harbor.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --email)
      if [[ $# -lt 2 || "${2:-}" == --* ]]; then
        printf 'Missing value for --email.\n' >&2
        exit 1
      fi
      LETSENCRYPT_EMAIL="${2:-}"
      shift 2
      ;;
    --admin-password)
      if [[ $# -lt 2 || "${2:-}" == --* ]]; then
        printf 'Missing value for --admin-password.\n' >&2
        exit 1
      fi
      HARBOR_ADMIN_PASSWORD="${2:-}"
      shift 2
      ;;
    --kubeconfig)
      if [[ $# -lt 2 || "${2:-}" == --* ]]; then
        printf 'Missing value for --kubeconfig.\n' >&2
        exit 1
      fi
      KUBECONFIG_PATH="${2:-}"
      shift 2
      ;;
    --letsencrypt-staging)
      LETSENCRYPT_STAGING="true"
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

if [[ -z "${LETSENCRYPT_EMAIL}" ]]; then
  cat >&2 <<'EOF'
Missing --email.

cert-manager needs this for the Let's Encrypt ACME account.
Let's Encrypt uses it for account registration, expiry notices,
and rate-limit/abuse contact. It is not used by Harbor.
EOF
  exit 1
fi

if [[ -z "${HARBOR_ADMIN_PASSWORD}" ]]; then
  printf 'Missing --admin-password.\n' >&2
  exit 1
fi

for cmd in kubectl helm curl openssl; do
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

if [[ "${LETSENCRYPT_STAGING}" == "true" ]]; then
  LETSENCRYPT_SERVER="https://acme-staging-v02.api.letsencrypt.org/directory"
else
  LETSENCRYPT_SERVER="https://acme-v02.api.letsencrypt.org/directory"
fi

HARBOR_SECRET_KEY=""
HARBOR_GATEWAY_IP=""
HARBOR_HOST=""

if [[ -f "${ENV_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
  HARBOR_SECRET_KEY="${HARBOR_SECRET_KEY:-}"
  HARBOR_GATEWAY_IP="${HARBOR_GATEWAY_IP:-}"
  HARBOR_HOST="${HARBOR_HOST:-}"
fi

if [[ -z "${HARBOR_SECRET_KEY}" ]]; then
  HARBOR_SECRET_KEY="$(openssl rand -hex 8)"
fi

write_env_file() {
  umask 077
  cat >"${ENV_FILE}" <<EOF
HARBOR_GATEWAY_IP=${HARBOR_GATEWAY_IP}
HARBOR_HOST=${HARBOR_HOST}
HARBOR_SECRET_KEY=${HARBOR_SECRET_KEY}
LETSENCRYPT_SERVER=${LETSENCRYPT_SERVER}
EOF
}

cleanup() {
  if [[ -n "${HARBOR_OVERRIDE_FILE}" && -f "${HARBOR_OVERRIDE_FILE}" ]]; then
    rm -f "${HARBOR_OVERRIDE_FILE}"
  fi
}
trap cleanup EXIT

yaml_quote() {
  local value="$1"
  value="${value//\'/\'\'}"
  printf "'%s'" "${value}"
}

wait_for_gateway_ip() {
  local ip=""
  for _ in {1..60}; do
    ip="$(kubectl -n "${HARBOR_NAMESPACE}" get gateway harbor-gateway -o jsonpath='{range .status.addresses[*]}{.value}{"\n"}{end}' 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -n 1 || true)"
    if [[ -n "${ip}" ]]; then
      printf '%s\n' "${ip}"
      return 0
    fi
    sleep 10
  done
  return 1
}

wait_for_https_endpoint() {
  local url="$1"
  local attempts="${2:-60}"
  local sleep_seconds="${3:-5}"

  for attempt in $(seq 1 "${attempts}"); do
    if curl -fsSI --connect-timeout 5 "${url}" >/dev/null; then
      return 0
    fi

    printf 'Waiting for HTTPS endpoint %s (%s/%s)...\n' "${url}" "${attempt}" "${attempts}"
    sleep "${sleep_seconds}"
  done

  printf 'HTTPS endpoint did not become reachable: %s\n' "${url}" >&2
  printf '\nGateway status:\n' >&2
  kubectl -n "${HARBOR_NAMESPACE}" get gateway harbor-gateway -o wide >&2 || true
  printf '\nCertificate status:\n' >&2
  kubectl -n "${HARBOR_NAMESPACE}" get certificate "${HARBOR_SECRET_NAME}" -o wide >&2 || true
  printf '\nEnvoy Gateway services and pods:\n' >&2
  kubectl -n "${ENVOY_NAMESPACE}" get svc,pods -o wide >&2 || true
  return 1
}

printf 'Using kubeconfig: %s\n' "${KUBECONFIG}"

printf 'Installing Envoy Gateway...\n'
helm upgrade --install eg oci://docker.io/envoyproxy/gateway-helm \
  --version "${ENVOY_GATEWAY_CHART_VERSION}" \
  --namespace "${ENVOY_NAMESPACE}" \
  --create-namespace \
  --wait \
  --timeout 10m

kubectl -n "${ENVOY_NAMESPACE}" wait deployment/envoy-gateway \
  --for=condition=Available \
  --timeout=5m

printf 'Creating Envoy GatewayClass...\n'
cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: eg
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller
EOF

printf 'Creating Harbor namespace and bootstrap Gateway...\n'
kubectl create namespace "${HARBOR_NAMESPACE}" --dry-run=client -o yaml | kubectl apply -f -

cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: harbor-gateway
  namespace: ${HARBOR_NAMESPACE}
spec:
  gatewayClassName: eg
  listeners:
    - name: http
      protocol: HTTP
      port: 80
      allowedRoutes:
        namespaces:
          from: Same
EOF

printf 'Waiting for Envoy Gateway LoadBalancer IP...\n'
HARBOR_GATEWAY_IP="$(wait_for_gateway_ip)"
HARBOR_HOST="harbor.${HARBOR_GATEWAY_IP}.sslip.io"
write_env_file

printf 'Gateway IP: %s\n' "${HARBOR_GATEWAY_IP}"
printf 'Harbor host: %s\n' "${HARBOR_HOST}"

printf 'Installing cert-manager with Gateway API support...\n'
helm upgrade --install cert-manager oci://quay.io/jetstack/charts/cert-manager \
  --version "${CERT_MANAGER_CHART_VERSION}" \
  --namespace "${CERT_MANAGER_NAMESPACE}" \
  --create-namespace \
  --set crds.enabled=true \
  --set config.enableGatewayAPI=true \
  --wait \
  --timeout 10m

kubectl -n "${CERT_MANAGER_NAMESPACE}" rollout restart deployment cert-manager
kubectl -n "${CERT_MANAGER_NAMESPACE}" rollout status deployment cert-manager --timeout=5m

printf "Creating Let's Encrypt ClusterIssuer...\n"
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-harbor
spec:
  acme:
    email: ${LETSENCRYPT_EMAIL}
    server: ${LETSENCRYPT_SERVER}
    privateKeySecretRef:
      name: letsencrypt-harbor-account-key
    solvers:
      - http01:
          gatewayHTTPRoute:
            parentRefs:
              - name: harbor-gateway
                namespace: ${HARBOR_NAMESPACE}
                kind: Gateway
EOF

printf 'Installing Harbor as an internal ClusterIP service...\n'
HARBOR_OVERRIDE_FILE="$(mktemp "${TMPDIR:-/tmp}/harbor-values.XXXXXX.yaml")"
umask 077
cat >"${HARBOR_OVERRIDE_FILE}" <<EOF
externalURL: $(yaml_quote "https://${HARBOR_HOST}")
harborAdminPassword: $(yaml_quote "${HARBOR_ADMIN_PASSWORD}")
secretKey: $(yaml_quote "${HARBOR_SECRET_KEY}")
EOF

helm repo add harbor https://helm.goharbor.io >/dev/null 2>&1 || true
helm repo update harbor
helm upgrade --install "${HARBOR_RELEASE}" harbor/harbor \
  --namespace "${HARBOR_NAMESPACE}" \
  --version "${HARBOR_CHART_VERSION}" \
  --values "${REPO_DIR}/configs/harbor/values.yaml" \
  --values "${HARBOR_OVERRIDE_FILE}" \
  --wait \
  --timeout 20m

printf 'Applying Certificate, final Gateway, and HTTPRoute...\n'
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: ${HARBOR_SECRET_NAME}
  namespace: ${HARBOR_NAMESPACE}
spec:
  secretName: ${HARBOR_SECRET_NAME}
  issuerRef:
    name: letsencrypt-harbor
    kind: ClusterIssuer
  dnsNames:
    - ${HARBOR_HOST}
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  name: harbor-gateway
  namespace: ${HARBOR_NAMESPACE}
spec:
  gatewayClassName: eg
  listeners:
    - name: http
      hostname: ${HARBOR_HOST}
      protocol: HTTP
      port: 80
      allowedRoutes:
        namespaces:
          from: Same
    - name: https
      hostname: ${HARBOR_HOST}
      protocol: HTTPS
      port: 443
      tls:
        mode: Terminate
        certificateRefs:
          - name: ${HARBOR_SECRET_NAME}
      allowedRoutes:
        namespaces:
          from: Same
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: harbor
  namespace: ${HARBOR_NAMESPACE}
spec:
  parentRefs:
    - name: harbor-gateway
      sectionName: http
    - name: harbor-gateway
      sectionName: https
  hostnames:
    - ${HARBOR_HOST}
  rules:
    - backendRefs:
        - name: harbor
          port: 80
EOF

printf 'Waiting for Harbor certificate to become ready...\n'
kubectl -n "${HARBOR_NAMESPACE}" wait certificate "${HARBOR_SECRET_NAME}" \
  --for=condition=Ready \
  --timeout=15m

printf 'Verifying Harbor HTTPS endpoint...\n'
wait_for_https_endpoint "https://${HARBOR_HOST}" 60 5

cat <<EOF

Harbor is available at:
  https://${HARBOR_HOST}

Local state saved to:
  ${ENV_FILE}

Next steps:
  1. Open the Harbor UI and log in as admin.
  2. Create a Docker Hub registry endpoint.
  3. Create a private dockerhub proxy-cache project.
  4. Configure scheduled replication for selected Docker Hub repositories.
  5. Create pull credentials and Kubernetes imagePullSecrets.

See MANUAL_DEPLOYMENT_HARBOR.md for the runbook.
EOF
