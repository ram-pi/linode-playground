# Linode Cleanup Utilities

A collection of cleanup scripts to remove orphaned or unused Linode resources. These utilities help you maintain a clean account by removing resources that are no longer in use.

## Quick Start

Run all cleanup scripts at once:

```bash
cd utils
./cleanup.sh
```

Or run individual cleanup scripts:

```bash
./cleanup_firewalls.sh
./cleanup_nodebalancers.sh
./cleanup_private_images.sh
./cleanup_volumes.sh
```

## Prerequisites

- **linode-cli** - Linode CLI tool ([installation guide](https://www.linode.com/docs/products/tools/cli/get-started/))
- **jq** - JSON processor for parsing CLI output

Install prerequisites:

```bash
# macOS
brew install jq
pip install linode-cli

# Linux (Debian/Ubuntu)
sudo apt-get install jq
pip install linode-cli

# Linux (RHEL/CentOS)
sudo yum install jq
pip install linode-cli
```

Configure Linode CLI:

```bash
linode-cli configure
```

## Master Cleanup Script

The `cleanup.sh` master script automatically discovers and runs all `cleanup_*.sh` scripts in the directory.

**Features:**
- **Dynamic discovery**: Automatically finds all cleanup scripts
- **Zero configuration**: Add new cleanup scripts and they're automatically included
- **Safe execution**: Prompts for confirmation before running
- **Error handling**: Tracks success/failure of each script
- **Colored output**: Easy-to-read status messages
- **Summary report**: Shows which scripts succeeded or failed

**Usage:**

```bash
./cleanup.sh
```

The script will:
1. Check for required dependencies (linode-cli, jq)
2. List all cleanup scripts found
3. Ask for confirmation
4. Run each script in alphabetical order
5. Display a summary of results

## Individual Cleanup Scripts

### cleanup_firewalls.sh
Removes Cloud Firewalls that have no attached entities (Linodes, NodeBalancers, etc.).

**What it cleans:**
- Orphaned Cloud Firewall rules

### cleanup_nodebalancers.sh
Removes all NodeBalancers from your account.

**What it cleans:**
- All NodeBalancer instances

⚠️ **Warning**: This removes ALL NodeBalancers. Use with caution.

### cleanup_private_images.sh
Removes private/custom images from your account.

**What it cleans:**
- User-uploaded images
- Custom images created from Linodes

### cleanup_volumes.sh
Removes unattached Block Storage volumes.

**What it cleans:**
- Volumes not attached to any Linode instance

## Adding New Cleanup Scripts

To add a new cleanup script:

1. Create a new file following the naming pattern: `cleanup_<resource>.sh`
2. Make it executable: `chmod +x cleanup_<resource>.sh`
3. Follow the existing script structure (see template below)

The master `cleanup.sh` script will automatically discover and run it.

**Template:**

```bash
#!/usr/bin/env bash

# Check if linode-cli is installed
if ! command -v linode-cli &> /dev/null; then
    echo "Error: linode-cli is not installed."
    echo "Please install linode-cli first."
    exit 1
fi

echo "========================================="
echo "Cleaning Up <Resource Name>"
echo "========================================="
echo ""

# Your cleanup logic here
# Use linode-cli commands and jq for JSON parsing

# Example:
resources=$(linode-cli <command> list --json | jq -r '.[].id')

if [ -z "$resources" ]; then
    echo "No <resources> found."
else
    for resource_id in $resources; do
        echo "Deleting <resource> with ID: $resource_id"
        linode-cli <command> delete "$resource_id"
        echo "✓ Deleted <resource> ID: $resource_id"
    done
fi
```

## Safety Notes

- **Review before running**: Always check what resources will be deleted
- **No undo**: Deleted resources cannot be recovered
- **Billing impact**: Removing resources may affect your services
- **Test first**: Run individual scripts to understand their behavior

## Examples

**Run master cleanup with all checks:**
```bash
./cleanup.sh
# Review the list of scripts
# Type 'y' to confirm
```

**Run specific cleanup:**
```bash
./cleanup_volumes.sh
```

**Dry-run (manual check before cleanup):**
```bash
# List orphaned firewalls
linode-cli firewalls list --json | jq -r '.[] | select(.entities | length == 0) | .id'

# Then run cleanup if satisfied
./cleanup_firewalls.sh
```

## Troubleshooting

**"linode-cli is not installed"**
```bash
pip install linode-cli
linode-cli configure
```

**"jq is not installed"**
```bash
# macOS
brew install jq

# Linux
sudo apt-get install jq  # Debian/Ubuntu
sudo yum install jq      # RHEL/CentOS
```

**Permission denied**
```bash
chmod +x cleanup.sh
chmod +x cleanup_*.sh
```

## Resources

- [Linode CLI Documentation](https://www.linode.com/docs/products/tools/cli/get-started/)
- [jq Manual](https://stedolan.github.io/jq/manual/)
- [Linode API Documentation](https://www.linode.com/docs/api/)

---

**⚠️ Important**: Always verify resources before deletion. These scripts permanently remove resources from your account.
