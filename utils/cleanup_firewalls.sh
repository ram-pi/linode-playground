#!/usr/bin/env bash

# check if linode cli is installed
if ! command -v linode-cli &> /dev/null; then
    echo "Error: linode-cli is not installed."
    echo "Please install linode-cli first."
    exit 1
fi
echo "========================================="

echo "Cleaning Up Firewall Rules"
echo "========================================="
echo ""

# List all Firewall Rules
firewall_rules=$(linode-cli firewalls list --json | jq -r '.[] | select(.entities | length == 0) | .id')

if [ -z "$firewall_rules" ]; then
    echo "No Firewall Rules found."
else
    for fw_id in $firewall_rules; do
        echo "Deleting Firewall Rule with ID: $fw_id"
        linode-cli firewalls delete "$fw_id"
        echo "✓ Deleted Firewall Rule ID: $fw_id"
    done
fi
