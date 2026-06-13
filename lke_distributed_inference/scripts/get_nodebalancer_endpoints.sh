#!/usr/bin/env bash

set -euo pipefail

KUBECONFIG_FRA="${KUBECONFIG_FRA:-$PWD/kubeconfig-de-fra-2}"
KUBECONFIG_SEA="${KUBECONFIG_SEA:-$PWD/kubeconfig-us-sea}"

FRA_ENDPOINT=$(kubectl --kubeconfig "$KUBECONFIG_FRA" -n llm-inference get svc llm-api-gateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
SEA_ENDPOINT=$(kubectl --kubeconfig "$KUBECONFIG_SEA" -n llm-inference get svc llm-api-gateway -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "FRA endpoint: http://${FRA_ENDPOINT}"
echo "SEA endpoint: http://${SEA_ENDPOINT}"
