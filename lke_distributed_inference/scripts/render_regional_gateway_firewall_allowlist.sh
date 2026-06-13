#!/usr/bin/env bash

set -euo pipefail

KUBECONFIG_LON="${KUBECONFIG_LON:-$PWD/kubeconfig-gb-lon}"

if [[ -z "${LAPTOP_CIDR:-}" ]]; then
  echo "Error: LAPTOP_CIDR must be set, for example 203.0.113.10/32" >&2
  exit 1
fi

cidrs=("$LAPTOP_CIDR")

while IFS= read -r line; do
  for ip in $line; do
    if [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
      cidr="${ip}/32"
      exists=false
      for existing in "${cidrs[@]}"; do
        if [[ "$existing" == "$cidr" ]]; then
          exists=true
          break
        fi
      done
      if [[ "$exists" == "false" ]]; then
        cidrs+=("$cidr")
      fi
    fi
  done
done < <(
  kubectl --kubeconfig "$KUBECONFIG_LON" get nodes \
    -o jsonpath='{range .items[*]}{.status.addresses[?(@.type=="ExternalIP")].address}{"\n"}{end}'
)

for index in "${!cidrs[@]}"; do
  if [[ "$index" -gt 0 ]]; then
    printf ', '
  fi
  printf '"%s"' "${cidrs[$index]}"
done
printf '\n'
