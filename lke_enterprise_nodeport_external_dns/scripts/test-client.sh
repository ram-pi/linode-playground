#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${PROJECT_DIR}"

CLIENT_IP="$(tofu output -raw client_public_ipv4)"
SERVICE_FQDN="$(tofu output -raw service_fqdn)"
NODE_PORT="$(tofu output -raw node_port)"

ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new \
  -i client_key "root@${CLIENT_IP}" \
  "cloud-init status --wait >/dev/null && resolvectl query '${SERVICE_FQDN}' && getent ahostsv4 '${SERVICE_FQDN}' && curl --fail --show-error --retry 12 --retry-delay 5 'http://${SERVICE_FQDN}:${NODE_PORT}/'"
