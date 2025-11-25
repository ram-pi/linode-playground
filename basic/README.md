# Basic VM with Multi-Network Setup

Basic Linode VM setup demonstrating all three networking types: VPC, VLAN, and Private IP. Shows how to configure a single instance with multiple network interfaces for different use cases.

## Architecture

!![diagram](drawio.svg)

## Features

- **VPC Networking**: VM connected to VPC subnet with NAT 1:1 for public access
- **VLAN Interface**: Private VLAN (172.21.100.0/24) for Layer 2 connectivity
- **Private IP**: Backend IP (192.168.128.0/17) for datacenter-local communication
- **Cloud Firewall**: IP-based access control for your IP and internal networks
- **SSH Key Authentication**: Password authentication disabled for security
- **Cloud-init**: Automated package installation and configuration

## Quick Start

1. **Set your Linode API token:**
   ```bash
   export LINODE_TOKEN='your-token-here'
   ```

2. **Deploy:**
   ```bash
   ./start.sh
   ```

3. **Connect:**
   ```bash
   ssh -i /tmp/id_rsa root@<vm-ip>
   ```

4. **Clean up:**
   ```bash
   ./shutdown.sh
   ```

## Network Configuration

The VM has three network interfaces:

1. **VPC Interface** (10.10.2.0/24)
   - Primary interface with public NAT
   - Used for internet access

2. **VLAN Interface** (172.21.100.10/24)
   - Private Layer 2 network
   - For direct VM-to-VM communication

3. **Private IP** (192.168.128.0/17)
   - Datacenter-local backend network
   - Free bandwidth between Linodes in same datacenter

## Pre-installed Tools

Cloud-init installs:
- `jq` - JSON processor
- `postgresql-client` - PostgreSQL utilities
- `kubectl` - Kubernetes CLI

## Resources

- [VPC Documentation](https://www.linode.com/docs/products/networking/vpc/)
- [VLAN Documentation](https://www.linode.com/docs/products/networking/vlans/)
- [Private IP Documentation](https://www.linode.com/docs/guides/linux-static-ip-configuration/)
