#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${PROJECT_DIR}"

: "${LINODE_TOKEN:?Export LINODE_TOKEN with Linode Domains and LKE permissions.}"

for command_name in tofu linode-cli jq kubectl helm envsubst ssh; do
  if ! command -v "${command_name}" >/dev/null 2>&1; then
    printf 'Required command not found: %s\n' "${command_name}" >&2
    exit 1
  fi
done

export TF_VAR_k8s_version="${TF_VAR_k8s_version:-$(linode-cli lke tiered-versions-list enterprise --json | jq -r '.[].id' | sort -V | tail -n 1)}"

printf 'Using LKE Enterprise version %s\n' "${TF_VAR_k8s_version}"
tofu init -reconfigure
tofu plan -out=tfplan
tofu apply tfplan
rm -f tfplan

CLUSTER_ID="$(tofu output -raw cluster_id)"
SECONDARY_CLUSTER_ID="$(tofu output -raw secondary_cluster_id)"
DOMAIN_ID="$(tofu output -raw domain_id)"
DNS_ZONE="$(tofu output -raw dns_zone)"
SERVICE_FQDN="$(tofu output -raw service_fqdn)"
NODE_PORT="$(tofu output -raw node_port)"
LINODE_NS_IPS="$(tofu output -json linode_nameservers | jq -r 'join(" ")')"

linode-cli lke kubeconfig-view "${CLUSTER_ID}" --json \
  | jq -r '.[0].kubeconfig' \
  | base64 -d > kubeconfig-primary.yaml
linode-cli lke kubeconfig-view "${SECONDARY_CLUSTER_ID}" --json \
  | jq -r '.[0].kubeconfig' \
  | base64 -d > kubeconfig-secondary.yaml
chmod 600 kubeconfig-primary.yaml kubeconfig-secondary.yaml
export KUBECONFIG="${PROJECT_DIR}/kubeconfig-primary.yaml"

tofu output -raw client_private_key > client_key
chmod 600 client_key

kubectl wait --for=condition=Ready nodes --all --timeout=15m

DNS_ZONE="${DNS_ZONE}" LINODE_NS_IPS="${LINODE_NS_IPS}" \
  envsubst < configs/coredns-custom.yaml.tpl | kubectl apply -f -
kubectl -n kube-system rollout restart deployment/workload-coredns
kubectl -n kube-system rollout status deployment/workload-coredns --timeout=5m

kubectl create namespace external-dns --dry-run=client -o yaml | kubectl apply -f -
kubectl -n external-dns create secret generic linode-api-token \
  --from-literal=token="${LINODE_TOKEN}" \
  --dry-run=client -o yaml | kubectl apply -f -

helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/ --force-update
helm upgrade --install external-dns external-dns/external-dns \
  --version 1.22.0 \
  --namespace external-dns \
  --values configs/external-dns-values.yaml \
  --set-string "domainFilters[0]=${DNS_ZONE}" \
  --wait --timeout 5m

SERVICE_FQDN="${SERVICE_FQDN}" NODE_PORT="${NODE_PORT}" \
  envsubst < configs/hello.yaml.tpl | kubectl apply -f -
kubectl -n hello rollout status daemonset/hello --timeout=5m

echo "Waiting for ExternalDNS to reconcile ${SERVICE_FQDN}..."
for attempt in {1..30}; do
  if linode-cli domains records-list "${DOMAIN_ID}" --json 2>/dev/null \
    | jq -e --arg name "${SERVICE_FQDN%."${DNS_ZONE}"}" '.[] | select(.name == $name and .type == "A")' >/dev/null; then
    break
  fi
  if [[ "${attempt}" -eq 30 ]]; then
    echo "ExternalDNS did not create ${SERVICE_FQDN}; inspect: kubectl -n external-dns logs deployment/external-dns" >&2
    exit 1
  fi
  printf '.'
  sleep 10
done
echo

./scripts/test-client.sh
