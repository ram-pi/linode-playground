#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KUBE1="${SCRIPT_DIR}/kubeconfig-cluster-01"
KUBE2="${SCRIPT_DIR}/kubeconfig-cluster-02"
TOKEN_FILE="/tmp/cluster-01.skupper.token"
NAMESPACE="private"

POSTGRES_HOST="${POSTGRES_HOST:-}"
POSTGRES_PORT="${POSTGRES_PORT:-}"
POSTGRES_DB="${POSTGRES_DB:-}"
POSTGRES_USER="${POSTGRES_USER:-}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-}"
POSTGRES_CA_CERT_PATH="${POSTGRES_CA_CERT_PATH:-}"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing required command: $1" >&2; exit 1; }
}

need_cmd kubectl
need_cmd skupper
need_cmd helm
need_cmd tofu
need_cmd openssl

for cfg in "$KUBE1" "$KUBE2"; do
  if [[ ! -f "$cfg" ]]; then
    echo "Kubeconfig not found: $cfg" >&2
    exit 1
  fi
done

if [[ -z "$POSTGRES_HOST" ]]; then
  POSTGRES_HOST="$(cd "$SCRIPT_DIR" && tofu output -raw postgres_vm_public_ip)"
fi
if [[ -z "$POSTGRES_PORT" ]]; then
  POSTGRES_PORT="$(cd "$SCRIPT_DIR" && tofu output -raw postgres_port)"
fi
if [[ -z "$POSTGRES_DB" ]]; then
  POSTGRES_DB="$(cd "$SCRIPT_DIR" && tofu output -raw postgres_db_name)"
fi
if [[ -z "$POSTGRES_USER" ]]; then
  POSTGRES_USER="$(cd "$SCRIPT_DIR" && tofu output -raw postgres_db_user)"
fi
if [[ -z "$POSTGRES_PASSWORD" ]]; then
  POSTGRES_PASSWORD="$(cd "$SCRIPT_DIR" && tofu output -raw postgres_db_password)"
fi
if [[ -z "$POSTGRES_CA_CERT_PATH" ]]; then
  POSTGRES_CA_CERT_PATH="$(cd "$SCRIPT_DIR" && tofu output -raw postgres_ca_cert_path)"
fi

echo "Using external PostgreSQL endpoint: ${POSTGRES_HOST}:${POSTGRES_PORT}"

echo "Applying Kubernetes manifests (idempotent)..."
kubectl apply -f "${SCRIPT_DIR}/config/cluster-01.yaml" --kubeconfig "$KUBE1"
kubectl apply -f "${SCRIPT_DIR}/config/cluster-02.yaml" --kubeconfig "$KUBE2"

echo "Installing/updating Skupper CRDs on both clusters..."
kubectl apply -f https://skupper.io/v2/install.yaml --kubeconfig "$KUBE1"
kubectl apply -f https://skupper.io/v2/install.yaml --kubeconfig "$KUBE2"

# --- Skupper site creation (idempotent) ---
if skupper site status --kubeconfig "$KUBE1" -n "$NAMESPACE" >/dev/null 2>&1; then
  echo "Skupper site already exists on cluster-01, skipping creation."
else
  echo "Initializing Skupper site on cluster-01 in namespace ${NAMESPACE}..."
  skupper site create cluster-01 --enable-ha --enable-link-access --kubeconfig "$KUBE1" -n "$NAMESPACE"
fi

if skupper site status --kubeconfig "$KUBE2" -n "$NAMESPACE" >/dev/null 2>&1; then
  echo "Skupper site already exists on cluster-02, skipping creation."
else
  echo "Initializing Skupper site on cluster-02 in namespace ${NAMESPACE}..."
  skupper site create cluster-02 --enable-ha --kubeconfig "$KUBE2" -n "$NAMESPACE"
fi

# --- Link clusters (idempotent — skip if link already up) ---
if skupper link status --kubeconfig "$KUBE2" -n "$NAMESPACE" 2>/dev/null | grep -qi "ready\|configured\|cluster-01"; then
  echo "Link from cluster-02 → cluster-01 already exists, skipping token issue/redeem."
else
  echo "Creating link token from cluster-01..."
  skupper token issue "$TOKEN_FILE" --kubeconfig "$KUBE1" -n "$NAMESPACE"
  echo "Linking cluster-02 to cluster-01..."
  skupper token redeem "$TOKEN_FILE" --kubeconfig "$KUBE2" -n "$NAMESPACE"
fi

echo "Skupper status (cluster-01):"
skupper site status --kubeconfig "$KUBE1" --namespace "$NAMESPACE"
skupper link status --kubeconfig "$KUBE1" --namespace "$NAMESPACE"

echo "Skupper status (cluster-02):"
skupper site status --kubeconfig "$KUBE2" --namespace "$NAMESPACE"
skupper link status --kubeconfig "$KUBE2" --namespace "$NAMESPACE"

# --- Listeners on cluster-01 (delete-before-create is idempotent) ---
echo "Reconciling Skupper listeners on cluster-01..."
skupper listener delete podinfo --kubeconfig "$KUBE1" -n "$NAMESPACE" >/dev/null 2>&1 || true
skupper listener create podinfo 9898 --kubeconfig "$KUBE1" -n "$NAMESPACE"
skupper listener delete postgresql-db --kubeconfig "$KUBE1" -n "$NAMESPACE" >/dev/null 2>&1 || true
skupper listener create postgresql-db "${POSTGRES_PORT}" --kubeconfig "$KUBE1" -n "$NAMESPACE"

# --- Connectors on cluster-02 (delete-before-create is idempotent) ---
echo "Reconciling Skupper connectors on cluster-02..."
skupper connector delete podinfo --kubeconfig "$KUBE2" -n "$NAMESPACE" >/dev/null 2>&1 || true
skupper connector create podinfo 9898 --kubeconfig "$KUBE2" -n "$NAMESPACE"
skupper connector delete postgresql-db --kubeconfig "$KUBE2" -n "$NAMESPACE" >/dev/null 2>&1 || true
skupper connector create postgresql-db "${POSTGRES_PORT}" --host "${POSTGRES_HOST}" --kubeconfig "$KUBE2" -n "$NAMESPACE"

echo "Skupper listener list (cluster-01):"
skupper listener list --kubeconfig "$KUBE1" -n "$NAMESPACE"
echo "Skupper connector list (cluster-02):"
skupper connector list --kubeconfig "$KUBE2" -n "$NAMESPACE"

# --- Skupper console (idempotent via upgrade --install) ---
echo "Installing/upgrading Skupper network observer on cluster-01..."
helm upgrade --install skupper-network-observer oci://quay.io/skupper/helm/network-observer --version 2.1.3 \
  --kubeconfig "$KUBE1" --namespace "$NAMESPACE"
echo "Skupper network observer installed. Use port-forwarding to access the console."

echo "Done. Token saved at ${TOKEN_FILE}; remove it if no longer needed."

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------
PG_CLIENT_POD="$(kubectl --kubeconfig "$KUBE1" -n "$NAMESPACE" get pods -l app=pg-client -o jsonpath='{.items[0].metadata.name}')"
if [[ -z "$PG_CLIENT_POD" ]]; then
  echo "WARNING: Unable to find pg-client pod in namespace ${NAMESPACE} on cluster-01 — skipping tests." >&2
else
  echo "Testing podinfo access from cluster-01..."
  kubectl --kubeconfig "$KUBE1" -n "$NAMESPACE" exec "$PG_CLIENT_POD" -- sh -lc \
    "wget -qO- http://podinfo:9898 | head -c 200 && echo"

  echo "Testing PostgreSQL SSL connection from pg-client via Skupper (sslmode=require)..."
  kubectl --kubeconfig "$KUBE1" -n "$NAMESPACE" exec "$PG_CLIENT_POD" -- sh -lc \
    "PGPASSWORD='${POSTGRES_PASSWORD}' psql 'host=postgresql-db port=${POSTGRES_PORT} dbname=${POSTGRES_DB} user=${POSTGRES_USER} sslmode=require' -c 'select now() as connected_at, current_user as db_user;'"

  echo "Capturing certificate presented to pg-client via Skupper..."
  kubectl --kubeconfig "$KUBE1" -n "$NAMESPACE" exec "$PG_CLIENT_POD" -- sh -lc \
    "echo | openssl s_client -starttls postgres -connect postgresql-db:${POSTGRES_PORT} -showcerts 2>/tmp/postgres-s_client.log | awk '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/' > /tmp/postgres-through-skupper.crt"
  kubectl --kubeconfig "$KUBE1" -n "$NAMESPACE" exec "$PG_CLIENT_POD" -- sh -lc \
    "openssl x509 -in /tmp/postgres-through-skupper.crt -noout -subject -issuer -fingerprint -sha256"

  REMOTE_FP="$(kubectl --kubeconfig "$KUBE1" -n "$NAMESPACE" exec "$PG_CLIENT_POD" -- sh -lc \
    "openssl x509 -in /tmp/postgres-through-skupper.crt -noout -fingerprint -sha256 | cut -d= -f2")"
  if [[ -n "$POSTGRES_CA_CERT_PATH" && -f "$POSTGRES_CA_CERT_PATH" ]]; then
    LOCAL_FP="$(openssl x509 -in "$POSTGRES_CA_CERT_PATH" -noout -fingerprint -sha256 | cut -d= -f2)"
    echo "Local PostgreSQL server cert fingerprint : ${LOCAL_FP}"
    echo "Remote cert fingerprint seen from pg-client: ${REMOTE_FP}"
    if [[ "$LOCAL_FP" == "$REMOTE_FP" ]]; then
      echo "Result: TLS is end-to-end — Skupper is NOT terminating the PostgreSQL TLS connection."
    else
      echo "Result: Certificate differs from the VM cert — Skupper (or something in between) is terminating/re-encrypting TLS."
    fi
  else
    echo "Skipping local fingerprint comparison — cert file not found at '${POSTGRES_CA_CERT_PATH}'."
  fi
fi

# ---------------------------------------------------------------------------
# Print reusable test commands for manual re-runs
# ---------------------------------------------------------------------------
cat <<EOF

================================================================
 MANUAL TEST COMMANDS
================================================================

# Find pg-client pod:
kubectl --kubeconfig kubeconfig-cluster-01 -n ${NAMESPACE} get pods -l app=pg-client

# psql SSL test through Skupper:
PG_CLIENT_POD=\$(kubectl --kubeconfig kubeconfig-cluster-01 -n ${NAMESPACE} \\
  get pods -l app=pg-client -o jsonpath='{.items[0].metadata.name}')
kubectl --kubeconfig kubeconfig-cluster-01 -n ${NAMESPACE} exec "\$PG_CLIENT_POD" -- \\
  sh -lc "PGPASSWORD='${POSTGRES_PASSWORD}' psql \\
    'host=postgresql-db port=${POSTGRES_PORT} dbname=${POSTGRES_DB} user=${POSTGRES_USER} sslmode=require' \\
    -c 'select now() as connected_at, current_user as db_user;'"

# Capture TLS certificate seen through Skupper:
kubectl --kubeconfig kubeconfig-cluster-01 -n ${NAMESPACE} exec "\$PG_CLIENT_POD" -- \\
  sh -lc "echo | openssl s_client -starttls postgres -connect postgresql-db:${POSTGRES_PORT} \\
    -showcerts 2>/tmp/postgres-s_client.log \\
    | awk '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/' \\
    > /tmp/postgres-through-skupper.crt && \\
  openssl x509 -in /tmp/postgres-through-skupper.crt -noout -subject -issuer -fingerprint -sha256"

# Compare remote fingerprint against local CA cert:
#   Remote fingerprint (from inside the pod):
kubectl --kubeconfig kubeconfig-cluster-01 -n ${NAMESPACE} exec "\$PG_CLIENT_POD" -- \\
  sh -lc "openssl x509 -in /tmp/postgres-through-skupper.crt -noout -fingerprint -sha256"
#   Local fingerprint (on this machine):
openssl x509 -in "${POSTGRES_CA_CERT_PATH}" -noout -fingerprint -sha256

# podinfo smoke-test:
kubectl --kubeconfig kubeconfig-cluster-01 -n ${NAMESPACE} exec "\$PG_CLIENT_POD" -- \\
  sh -lc "wget -qO- http://podinfo:9898 | head -c 200 && echo"

================================================================
EOF
