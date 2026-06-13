#!/usr/bin/env bash

set -euo pipefail

KUBECONFIG_LON="${KUBECONFIG_LON:-$PWD/kubeconfig-gb-lon}"

LITELLM_ENDPOINT=$(kubectl --kubeconfig "$KUBECONFIG_LON" -n litellm-gateway get svc litellm -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "LiteLLM endpoint: http://${LITELLM_ENDPOINT}"
