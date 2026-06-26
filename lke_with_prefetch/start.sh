#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${YELLOW}Starting Dragonfly prefetch LKE deployment...${NC}"

# Check for required environment variable
if [ -z "$LINODE_TOKEN" ]; then
    echo -e "${RED}Error: LINODE_TOKEN environment variable is not set${NC}"
    exit 1
fi

# Export token for OpenTofu
export TF_VAR_linode_token="$LINODE_TOKEN"

# Initialize and apply OpenTofu
echo -e "${YELLOW}Initializing OpenTofu...${NC}"
cd "$SCRIPT_DIR"
tofu init

echo -e "${YELLOW}Applying OpenTofu configuration...${NC}"
tofu apply -auto-approve

# Get kubeconfig
echo -e "${YELLOW}Extracting kubeconfig...${NC}"
export KUBECONFIG="$SCRIPT_DIR/kubeconfig.yaml"

# Wait for cluster to be ready
echo -e "${YELLOW}Waiting for cluster to be ready...${NC}"
for i in {1..60}; do
    if kubectl cluster-info &>/dev/null; then
        echo -e "${GREEN}Cluster is ready!${NC}"
        break
    fi
    echo "Attempt $i/60: Waiting for cluster..."
    sleep 10
done

# Get cluster info
echo -e "${YELLOW}Cluster Information:${NC}"
CLUSTER_ID=$(tofu output -raw cluster_id 2>/dev/null)
CLUSTER_LABEL=$(tofu output -raw cluster_label 2>/dev/null)
API_ENDPOINTS=$(tofu output -json api_endpoints 2>/dev/null)

echo -e "${GREEN}✓ Cluster ID: $CLUSTER_ID${NC}"
echo -e "${GREEN}✓ Cluster Label: $CLUSTER_LABEL${NC}"
echo -e "${GREEN}✓ Kubeconfig: $KUBECONFIG${NC}"
echo -e "${GREEN}✓ API Endpoints: $API_ENDPOINTS${NC}"

echo -e "\n${YELLOW}Next steps:${NC}"
echo -e "1. Set your kubeconfig: ${GREEN}export KUBECONFIG=$KUBECONFIG${NC}"
echo -e "2. Verify cluster: ${GREEN}kubectl get nodes${NC}"
echo -e "3. Follow MANUAL_DEPLOYMENT_DRAGONFLY.md for Dragonfly + kube-fledged setup${NC}"
echo -e "\n${GREEN}LKE cluster provisioning complete!${NC}"
