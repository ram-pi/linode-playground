#!/usr/bin/env bash

set -uo pipefail

DELETE_MODE=0

usage() {
    cat <<'EOF'
Usage: cleanup_nodebalancers.sh [--delete]

Modes:
  default   Dry-run. Shows which NodeBalancers would be deleted.
  --delete  Actually delete unused NodeBalancers.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --delete)
            DELETE_MODE=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown argument: $1"
            echo ""
            usage
            exit 1
            ;;
    esac
done

# check if linode cli is installed
if ! command -v linode-cli &> /dev/null; then
    echo "Error: linode-cli is not installed."
    echo "Please install linode-cli first."
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed."
    echo "Please install jq first."
    exit 1
fi

echo "========================================="

echo "Cleaning Up NodeBalancers"
echo "========================================="
if [ "$DELETE_MODE" -eq 1 ]; then
    echo "Mode: DELETE (changes will be applied)"
else
    echo "Mode: DRY-RUN (no changes will be applied)"
    echo "Pass --delete to actually remove NodeBalancers."
fi
echo ""

# List all NodeBalancers
nodebalancers_json=$(linode-cli nodebalancers list --json)
nodebalancer_count=$(jq 'length' <<< "$nodebalancers_json")

if [ "$nodebalancer_count" -eq 0 ]; then
    echo "No NodeBalancers found."
else
    deleted_count=0
    kept_count=0
    would_delete_count=0

    for nb_id in $(jq -r '.[].id' <<< "$nodebalancers_json"); do
        echo "Evaluating NodeBalancer ID: $nb_id"

        configs_json=$(linode-cli nodebalancers configs-list "$nb_id" --json)
        config_count=$(jq 'length' <<< "$configs_json")

        # If no configs exist, the NodeBalancer is considered unused.
        if [ "$config_count" -eq 0 ]; then
            if [ "$DELETE_MODE" -eq 1 ]; then
                echo "  -> No configs found. Deleting unused NodeBalancer."
                linode-cli nodebalancers delete "$nb_id"
                echo "  ✓ Deleted NodeBalancer ID: $nb_id"
                deleted_count=$((deleted_count + 1))
            else
                echo "  -> No configs found. Would delete unused NodeBalancer (dry-run)."
                would_delete_count=$((would_delete_count + 1))
            fi
            continue
        fi

        has_working_backend=0

        for cfg_id in $(jq -r '.[].id' <<< "$configs_json"); do
            nodes_json=$(linode-cli nodebalancers nodes-list "$nb_id" "$cfg_id" --json)

            # Working backend definition:
            # - mode is "accept"
            # - address exists
            # - status is "up" (or empty when status is not reported)
            working_count=$(jq '[.[]
                | select((.address // "") != "")
                | select((.mode // "" | ascii_downcase) == "accept")
                | select((((.status // "") | ascii_downcase) == "up") or ((.status // "") == ""))
              ] | length' <<< "$nodes_json")

            if [ "$working_count" -gt 0 ]; then
                has_working_backend=1
                break
            fi
        done

        if [ "$has_working_backend" -eq 1 ]; then
            echo "  -> Has at least one working backend. Keeping NodeBalancer."
            kept_count=$((kept_count + 1))
        else
            if [ "$DELETE_MODE" -eq 1 ]; then
                echo "  -> No working backends found. Deleting unused NodeBalancer."
                linode-cli nodebalancers delete "$nb_id"
                echo "  ✓ Deleted NodeBalancer ID: $nb_id"
                deleted_count=$((deleted_count + 1))
            else
                echo "  -> No working backends found. Would delete unused NodeBalancer (dry-run)."
                would_delete_count=$((would_delete_count + 1))
            fi
        fi
    done

    echo ""
    echo "========================================="
    echo "Summary"
    echo "========================================="
    if [ "$DELETE_MODE" -eq 1 ]; then
        echo "Deleted NodeBalancers: $deleted_count"
    else
        echo "Would delete NodeBalancers: $would_delete_count"
    fi
    echo "Kept NodeBalancers: $kept_count"
fi
