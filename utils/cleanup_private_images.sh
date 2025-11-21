#!/usr/bin/env bash

# check if linode cli is installed
if ! command -v linode-cli &> /dev/null; then
    echo "Error: linode-cli is not installed."
    echo "Please install linode-cli first."
    exit 1
fi
echo "========================================="

echo "Cleaning Up Private Linode Images"
echo "========================================="
echo ""
# List all images and filter for private ones
private_images=$(linode-cli images list --json | jq -r '.[] | select(.is_public == false) | .id')

if [ -z "$private_images" ]; then
    echo "No private images found."
else
    for image_id in $private_images; do
        echo "Deleting private image with ID: $image_id"
        linode-cli images delete "$image_id"
        echo "✓ Deleted image ID: $image_id"
    done
fi
