#!/usr/bin/env bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}  Linode Resource Inventory${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# Check if linode-cli is installed
if ! command -v linode-cli &> /dev/null; then
    echo -e "${RED}Error: linode-cli is not installed.${NC}"
    echo "Please install linode-cli first:"
    echo "  pip install linode-cli"
    exit 1
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is not installed.${NC}"
    echo "Please install jq first:"
    echo "  macOS: brew install jq"
    echo "  Linux: sudo apt-get install jq / sudo yum install jq"
    exit 1
fi

echo -e "${GREEN}✓ Prerequisites check passed${NC}"
echo ""

# Function to print section header
print_section() {
    echo ""
    echo -e "${CYAN}=========================================${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}=========================================${NC}"
}

# Function to count and display resources
count_resources() {
    local count=$1
    local resource_type=$2

    if [ "$count" -eq 0 ]; then
        echo -e "${YELLOW}No $resource_type found${NC}"
    else
        echo -e "${GREEN}Found $count $resource_type${NC}"
    fi
}

# Linodes (Instances)
print_section "Linode Instances"
linodes=$(linode-cli linodes list --json)
linode_count=$(echo "$linodes" | jq '. | length')
count_resources "$linode_count" "instance(s)"
if [ "$linode_count" -gt 0 ]; then
    echo "$linodes" | jq -r '.[] | "  • \(.label) (\(.id)) - \(.type) - \(.region) - \(.status)"'
fi

# NodeBalancers
print_section "NodeBalancers"
nodebalancers=$(linode-cli nodebalancers list --json)
nb_count=$(echo "$nodebalancers" | jq '. | length')
count_resources "$nb_count" "nodebalancer(s)"
if [ "$nb_count" -gt 0 ]; then
    echo "$nodebalancers" | jq -r '.[] | "  • \(.label) (\(.id)) - \(.region) - \(.ipv4)"'
fi

# Volumes (Block Storage)
print_section "Block Storage Volumes"
volumes=$(linode-cli volumes list --json)
vol_count=$(echo "$volumes" | jq '. | length')
count_resources "$vol_count" "volume(s)"
if [ "$vol_count" -gt 0 ]; then
    echo "$volumes" | jq -r '.[] | "  • \(.label) (\(.id)) - \(.size)GB - \(.region) - \(.status) - Attached: \(if .linode_id then "Yes (\(.linode_id))" else "No" end)"'
fi

# Firewalls
print_section "Cloud Firewalls"
firewalls=$(linode-cli firewalls list --json)
fw_count=$(echo "$firewalls" | jq '. | length')
count_resources "$fw_count" "firewall(s)"
if [ "$fw_count" -gt 0 ]; then
    echo "$firewalls" | jq -r '.[] | "  • \(.label) (\(.id)) - Status: \(.status) - Entities: \(.entities | length) - Tags: \(.tags | join(", "))"'
fi

# VPCs
print_section "VPCs"
vpcs=$(linode-cli vpcs list --json)
vpc_count=$(echo "$vpcs" | jq '. | length')
count_resources "$vpc_count" "VPC(s)"
if [ "$vpc_count" -gt 0 ]; then
    echo "$vpcs" | jq -r '.[] | "  • \(.label) (\(.id)) - \(.region) - Subnets: \(.subnets | length)"'
fi

# VLANs
print_section "VLANs"
vlans=$(linode-cli vlans list --json)
vlan_count=$(echo "$vlans" | jq '. | length')
count_resources "$vlan_count" "VLAN(s)"
if [ "$vlan_count" -gt 0 ]; then
    echo "$vlans" | jq -r '.[] | "  • \(.label) - \(.region) - CIDR: \(.cidr_block // "N/A") - Linodes: \(.linodes | length)"'
fi

# LKE Clusters
print_section "LKE Clusters"
lke_clusters=$(linode-cli lke clusters-list --json 2>/dev/null || echo "[]")
lke_count=$(echo "$lke_clusters" | jq '. | length')
count_resources "$lke_count" "LKE cluster(s)"
if [ "$lke_count" -gt 0 ]; then
    echo "$lke_clusters" | jq -r '.[] | "  • \(.label) (\(.id)) - K8s \(.k8s_version) - \(.region) - Control Plane: \(if .control_plane.high_availability then "HA" else "Standard" end)"'
fi

# Object Storage Buckets
print_section "Object Storage Buckets"
clusters=$(linode-cli object-storage clusters-list --json 2>/dev/null | jq -r '.[].id' || echo "")
bucket_count=0
if [ -n "$clusters" ]; then
    while IFS= read -r cluster_id; do
        obj_buckets_raw=$(linode-cli obj ls --cluster "$cluster_id" 2>/dev/null || echo "")
        if [ -n "$obj_buckets_raw" ]; then
            cluster_bucket_count=$(echo "$obj_buckets_raw" | wc -l | tr -d ' ')
            bucket_count=$((bucket_count + cluster_bucket_count))
            echo "$obj_buckets_raw" | while read -r bucket; do
                echo "  • $bucket (cluster: $cluster_id)"
            done
        fi
    done <<< "$clusters"
fi
count_resources "$bucket_count" "bucket(s)"

# Object Storage Keys
print_section "Object Storage Keys"
obj_keys=$(linode-cli object-storage keys-list --json 2>/dev/null || echo "[]")
key_count=$(echo "$obj_keys" | jq '. | length')
count_resources "$key_count" "access key(s)"
if [ "$key_count" -gt 0 ]; then
    echo "$obj_keys" | jq -r '.[] | "  • \(.label) (\(.id)) - Regions: \(.regions | map(.id) | join(", ")) - Limited: \(.limited)"'
fi

# Domains
print_section "Domains"
domains=$(linode-cli domains list --json)
domain_count=$(echo "$domains" | jq '. | length')
count_resources "$domain_count" "domain(s)"
if [ "$domain_count" -gt 0 ]; then
    echo "$domains" | jq -r '.[] | "  • \(.domain) (\(.id)) - Type: \(.type) - Status: \(.status)"'
fi

# Images (Private/Custom)
print_section "Private Images"
images=$(linode-cli images list --json | jq '[.[] | select(.is_public == false)]')
image_count=$(echo "$images" | jq '. | length')
count_resources "$image_count" "private image(s)"
if [ "$image_count" -gt 0 ]; then
    echo "$images" | jq -r '.[] | "  • \(.label) (\(.id)) - \(.size)MB - \(.status) - Created: \(.created)"'
fi

# StackScripts
print_section "StackScripts"
stackscripts=$(linode-cli stackscripts list --json | jq '[.[] | select(.is_public == false)]')
ss_count=$(echo "$stackscripts" | jq '. | length')
count_resources "$ss_count" "stackscript(s)"
if [ "$ss_count" -gt 0 ]; then
    echo "$stackscripts" | jq -r '.[] | "  • \(.label) (\(.id)) - Deployments: \(.deployments_total)"'
fi

# Databases
print_section "Managed Databases"
databases=$(linode-cli databases list --json 2>/dev/null || echo "[]")
db_count=$(echo "$databases" | jq '. | length')
count_resources "$db_count" "database(s)"
if [ "$db_count" -gt 0 ]; then
    echo "$databases" | jq -r '.[] | "  • \(.label) (\(.id)) - \(.engine) - \(.region) - Status: \(.status)"'
fi

# Summary
print_section "Summary"
echo -e "  Linodes:           ${GREEN}$linode_count${NC}"
echo -e "  NodeBalancers:     ${GREEN}$nb_count${NC}"
echo -e "  Volumes:           ${GREEN}$vol_count${NC}"
echo -e "  Firewalls:         ${GREEN}$fw_count${NC}"
echo -e "  VPCs:              ${GREEN}$vpc_count${NC}"
echo -e "  VLANs:             ${GREEN}$vlan_count${NC}"
echo -e "  LKE Clusters:      ${GREEN}$lke_count${NC}"
echo -e "  Object Buckets:    ${GREEN}$bucket_count${NC}"
echo -e "  Object Keys:       ${GREEN}$key_count${NC}"
echo -e "  Domains:           ${GREEN}$domain_count${NC}"
echo -e "  Private Images:    ${GREEN}$image_count${NC}"
echo -e "  StackScripts:      ${GREEN}$ss_count${NC}"
echo -e "  Databases:         ${GREEN}$db_count${NC}"

echo ""
echo -e "${BLUE}=========================================${NC}"
echo -e "${GREEN}✓ Resource inventory complete${NC}"
echo -e "${BLUE}=========================================${NC}"
