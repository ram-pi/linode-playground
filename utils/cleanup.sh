#!/usr/bin/env bash

# Don't use set -e here since we want to continue even if subscripts fail
# We'll handle errors manually

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}  Linode Cleanup Master Script${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if linode-cli is installed (required by all cleanup scripts)
if ! command -v linode-cli &> /dev/null; then
    echo -e "${RED}Error: linode-cli is not installed.${NC}"
    echo "Please install linode-cli first:"
    echo "  pip install linode-cli"
    exit 1
fi

# Check if jq is installed (required by all cleanup scripts)
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is not installed.${NC}"
    echo "Please install jq first:"
    echo "  macOS: brew install jq"
    echo "  Linux: sudo apt-get install jq / sudo yum install jq"
    exit 1
fi

echo -e "${GREEN}✓ Prerequisites check passed${NC}"
echo ""

# Find all cleanup_*.sh scripts in the current directory (excluding this master script)
cleanup_scripts=($(find "$SCRIPT_DIR" -maxdepth 1 -name "cleanup_*.sh" -type f | sort))

if [ ${#cleanup_scripts[@]} -eq 0 ]; then
    echo -e "${YELLOW}No cleanup scripts found in $SCRIPT_DIR${NC}"
    exit 0
fi

echo -e "${BLUE}Found ${#cleanup_scripts[@]} cleanup script(s):${NC}"
for script in "${cleanup_scripts[@]}"; do
    echo -e "  - $(basename "$script")"
done
echo ""

# Ask for confirmation
read -p "$(echo -e ${YELLOW}"Do you want to run all cleanup scripts? (y/N): "${NC})" -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Cleanup cancelled.${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}  Starting Cleanup Process${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# Track success/failure
successful=0
failed=0
failed_scripts=()

# Run each cleanup script
for script in "${cleanup_scripts[@]}"; do
    script_name=$(basename "$script")
    echo -e "${BLUE}Running: ${script_name}${NC}"
    echo ""

    if bash "$script"; then
        echo ""
        echo -e "${GREEN}✓ ${script_name} completed successfully${NC}"
        ((successful++))
    else
        echo ""
        echo -e "${RED}✗ ${script_name} failed${NC}"
        ((failed++))
        failed_scripts+=("$script_name")
    fi

    echo ""
    echo -e "${BLUE}-----------------------------------------${NC}"
    echo ""
done

# Summary
echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}  Cleanup Summary${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""
echo -e "${GREEN}Successful: $successful${NC}"
echo -e "${RED}Failed: $failed${NC}"

if [ $failed -gt 0 ]; then
    echo ""
    echo -e "${RED}Failed scripts:${NC}"
    for script in "${failed_scripts[@]}"; do
        echo -e "  - ${script}"
    done
    exit 1
fi

echo ""
echo -e "${GREEN}✓ All cleanup scripts completed successfully!${NC}"
