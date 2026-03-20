#!/bin/bash

# cleanup-unattached-pvcs.sh
# Deletes Linode Block Storage volumes that are not attached to any Linode instance.
# Useful after destroying an LKE cluster, which leaves volumes orphaned.
#
# Usage:
#   ./cleanup-unattached-pvcs.sh              # dry-run
#   ./cleanup-unattached-pvcs.sh --delete     # actually delete
#   ./cleanup-unattached-pvcs.sh --region us-east --delete

set -euo pipefail

DRY_RUN=true
REGION_FILTER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --delete)
      DRY_RUN=false
      shift
      ;;
    --region|-r)
      REGION_FILTER="$2"
      shift 2
      ;;
    --help|-h)
      echo "Usage: $0 [--delete] [--region <region>]"
      echo "  Default: dry-run across all regions"
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

if $DRY_RUN; then
  echo "🔍 DRY-RUN mode (pass --delete to actually remove volumes)"
else
  echo "⚠️  DELETE mode enabled"
fi
[[ -n "$REGION_FILTER" ]] && echo "   Region filter: $REGION_FILTER"
echo ""

echo "📋 Fetching Linode volumes..."

VOLUMES_JSON=$(linode-cli volumes list --json 2>/dev/null)

# Filter unattached: linode_id is null or 0
UNATTACHED=$(echo "$VOLUMES_JSON" | jq '[.[] | select(.linode_id == null or .linode_id == 0)]')

if [[ -n "$REGION_FILTER" ]]; then
  UNATTACHED=$(echo "$UNATTACHED" | jq --arg region "$REGION_FILTER" '[.[] | select(.region == $region)]')
fi

TOTAL=$(echo "$UNATTACHED" | jq 'length')

if [[ "$TOTAL" -eq 0 ]]; then
  echo "✅ No unattached volumes found."
  exit 0
fi

echo "🔎 Found $TOTAL unattached volume(s):"
echo ""

DELETED=0

while IFS=$'\t' read -r id label region size status; do
  if $DRY_RUN; then
    echo "   🗑️  WOULD DELETE  id=$id  label=$label  region=$region  size=${size}GB  status=$status"
  else
    echo "   🗑️  Deleting  id=$id  label=$label  region=$region  size=${size}GB..."
    linode-cli volumes delete "$id"
    echo "      ✅ Deleted."
    (( DELETED++ )) || true
  fi
done < <(echo "$UNATTACHED" | jq -r '.[] | [.id, .label, .region, .size, .status] | @tsv')

echo ""
echo "=== Summary ==="
if $DRY_RUN; then
  echo "   Would delete : $TOTAL volume(s)"
  echo ""
  echo "   Run with --delete to remove them."
else
  echo "   Deleted : $DELETED volume(s)"
fi
