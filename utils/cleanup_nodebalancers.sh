#!/usr/bin/env bash

# check if linode cli is installed
if ! command -v linode-cli &> /dev/null; then
    echo "Error: linode-cli is not installed."
    echo "Please install linode-cli first."
    exit 1
fi
echo "========================================="

echo "Cleaning Up NodeBalancers"
echo "========================================="
echo ""

# List all NodeBalancers
nodebalancers=$(linode-cli nodebalancers list --json | jq -r '.[].id')

if [ -z "$nodebalancers" ]; then
    echo "No NodeBalancers found."
else
    for nb_id in $nodebalancers; do
        echo "Deleting NodeBalancer with ID: $nb_id"
        linode-cli nodebalancers delete "$nb_id"
        echo "✓ Deleted NodeBalancer ID: $nb_id"
    done
fi
