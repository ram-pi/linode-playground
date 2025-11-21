#!/usr/bin/env bash

# check if linode cli is installed
if ! command -v linode-cli &> /dev/null; then
    echo "Error: linode-cli is not installed."
    echo "Please install linode-cli first."
    exit 1
fi
echo "========================================="

echo "Cleaning Up Unused Linode Volumes"
echo "========================================="
echo ""
# List all volumes and filter for unattached ones
unattached_volumes=$(linode-cli volumes list --json | jq -r '.[] | select(.linode_id == null) | .id')

if [ -z "$unattached_volumes" ]; then
    echo "No unattached volumes found."
else
    for volume_id in $unattached_volumes; do
        echo "Deleting unattached volume with ID: $volume_id"
        linode-cli volumes delete "$volume_id"
        echo "✓ Deleted volume ID: $volume_id"
    done
fi
