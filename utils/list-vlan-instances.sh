#!/bin/bash

# list-vlan-instances.sh
# Lists all Linode instances that have a VLAN interface, showing their name and VLAN IP.
#
# Usage:
#   ./list-vlan-instances.sh
#   ./list-vlan-instances.sh --region us-east
#   ./list-vlan-instances.sh --vlan my-vlan-label

set -euo pipefail

REGION_FILTER=""
VLAN_LABEL_FILTER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --region|-r)
      REGION_FILTER="$2"
      shift 2
      ;;
    --vlan|-v)
      VLAN_LABEL_FILTER="$2"
      shift 2
      ;;
    --help|-h)
      echo "Usage: $0 [--region <region>] [--vlan <vlan-label>]"
      exit 0
      ;;
    *)
      echo "Unknown argument: $1"
      exit 1
      ;;
  esac
done

if ! command -v linode-cli &>/dev/null; then
  echo "❌ linode-cli not found in PATH"
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "❌ jq not found in PATH"
  exit 1
fi

echo "📋 Fetching Linode instances..."
[[ -n "$REGION_FILTER" ]]     && echo "   Region filter : $REGION_FILTER"
[[ -n "$VLAN_LABEL_FILTER" ]] && echo "   VLAN filter   : $VLAN_LABEL_FILTER"
echo ""

LINODES_JSON=$(linode-cli linodes list --json 2>/dev/null)

if [[ -n "$REGION_FILTER" ]]; then
  LINODES_JSON=$(echo "$LINODES_JSON" | jq --arg r "$REGION_FILTER" '[.[] | select(.region == $r)]')
fi

LINODE_IDS=$(echo "$LINODES_JSON" | jq -r '.[].id')
TOTAL_LINODES=$(echo "$LINODES_JSON" | jq 'length')
echo "🔎 Scanning $TOTAL_LINODES instance(s) for VLAN interfaces..."
echo ""

FOUND=0
printf "%-30s %-20s %-20s %-20s\n" "INSTANCE" "VLAN LABEL" "VLAN IP (IPAM)" "REGION"
printf "%-30s %-20s %-20s %-20s\n" "------------------------------" "--------------------" "--------------------" "--------------------"

while IFS= read -r linode_id; do
  linode_label=$(echo "$LINODES_JSON" | jq -r --argjson id "$linode_id" '.[] | select(.id == $id) | .label')
  linode_region=$(echo "$LINODES_JSON" | jq -r --argjson id "$linode_id" '.[] | select(.id == $id) | .region')

  configs_json=$(linode-cli linodes configs-list "$linode_id" --json 2>/dev/null)

  # Extract all VLAN interfaces across all configs
  vlan_ifaces=$(echo "$configs_json" | jq '[
    .[].interfaces[]?
    | select(.purpose == "vlan")
  ]')

  if [[ -n "$VLAN_LABEL_FILTER" ]]; then
    vlan_ifaces=$(echo "$vlan_ifaces" | jq --arg v "$VLAN_LABEL_FILTER" '[.[] | select(.label == $v)]')
  fi

  count=$(echo "$vlan_ifaces" | jq 'length')
  [[ "$count" -eq 0 ]] && continue

  while IFS=$'\t' read -r vlan_label ipam_address; do
    ipam_display="${ipam_address:-<no IPAM>}"
    printf "%-30s %-20s %-20s %-20s\n" "$linode_label" "$vlan_label" "$ipam_display" "$linode_region"
    (( FOUND++ )) || true
  done < <(echo "$vlan_ifaces" | jq -r '.[] | [.label, .ipam_address] | @tsv')

done <<< "$LINODE_IDS"

echo ""
if [[ "$FOUND" -eq 0 ]]; then
  echo "   No instances with VLAN interfaces found."
else
  echo "   Total VLAN interfaces found: $FOUND"
fi
