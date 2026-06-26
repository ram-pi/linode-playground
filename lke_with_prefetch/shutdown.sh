#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${YELLOW}Shutting down Dragonfly prefetch LKE deployment...${NC}"

# Check for required environment variable
if [ -z "$LINODE_TOKEN" ]; then
    echo -e "${RED}Error: LINODE_TOKEN environment variable is not set${NC}"
    exit 1
fi

export TF_VAR_linode_token="$LINODE_TOKEN"

cd "$SCRIPT_DIR"

# Destroy OpenTofu resources
echo -e "${YELLOW}Destroying OpenTofu resources...${NC}"
tofu destroy -auto-approve

# Clean up kubeconfig
if [ -f "$SCRIPT_DIR/kubeconfig.yaml" ]; then
    rm -f "$SCRIPT_DIR/kubeconfig.yaml"
    echo -e "${GREEN}✓ Removed kubeconfig${NC}"
fi

echo -e "${GREEN}Shutdown complete!${NC}"
