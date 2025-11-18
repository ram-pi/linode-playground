# Linode Examples

Practical examples and demos for Linode infrastructure. These projects showcase real-world patterns using various tools including Infrastructure-as-Code (OpenTofu), scripting, and automation.

## Prerequisites

Common requirements across projects:
- **Linode API Token** with read/write permissions ([get your token](https://cloud.linode.com/profile/tokens))

Project-specific requirements:
- **OpenTofu** v1.8.0+ (for IaC projects)
- **Python 3** with `linode_api4` (for firewall_by_tags)

## Quick Start

```bash
# Set your API token
export LINODE_TOKEN='your-token-here'

# Choose a project and run
cd <project-name>
./start.sh

# Clean up when done
./shutdown.sh
```

## Projects

### 🔥 Firewall Management by Tags
**[`firewall_by_tags/`](firewall_by_tags/)**

Automated firewall rule management using tag-based assignment. Combines OpenTofu provisioning with Python API automation to dynamically apply firewall rules based on instance tags.

**Demonstrates:**
- Tag-based resource management
- API automation with Python
- Firewall rule propagation timing
- Cloud-init web server setup

### 🔒 Private VM with NAT Gateway
**[`private_vm/`](private_vm/)**

Secure network architecture with a private VM isolated from the internet, accessing external resources through a NAT gateway. Shows VPC design with public/private subnets.

**Demonstrates:**
- VPC with 2 subnets (public + private)
- NAT gateway configuration with iptables
- LISH (Linode Interactive Shell Host) for console access
- VLAN for Layer 2 connectivity
- Multi-interface networking

## Resources

- [Linode Documentation](https://www.linode.com/docs/)
- [OpenTofu Documentation](https://opentofu.org/docs/)
- [Linode API Documentation](https://www.linode.com/docs/api/)

---

**⚠️ Remember:** Run `./shutdown.sh` after testing to avoid charges.
