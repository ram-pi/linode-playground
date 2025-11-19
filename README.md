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

### 🌐 Static Website with Object Storage
**[`static_website/`](static_website/)**

Deploy a static website using Linode Object Storage with automatic backup synchronization. Demonstrates cloud storage for web hosting with built-in redundancy.

**Demonstrates:**
- Object Storage bucket management
- Static website hosting with S3-compatible storage
- Automatic backup synchronization with rclone
- Bucket policies and public access configuration

**Additional tools required:** `s3cmd`, `rclone`

### 📊 Linode Prometheus Exporter
**[`linode_prometheus_exporter/`](linode_prometheus_exporter/)**

Prometheus exporter that exposes Linode resource metrics for monitoring and alerting. Includes a complete monitoring stack with Prometheus and Grafana, featuring a pre-built dashboard for visualizing your Linode infrastructure.

**Demonstrates:**
- Custom Prometheus exporter development
- Multi-platform Docker image with QEMU
- Docker Compose orchestration
- Grafana dashboard provisioning
- Python SDK integration with Linode API

**Metrics exposed:**
- Linode instances, volumes, VPCs, VLANs
- LKE clusters (standard and HA)
- Object Storage buckets
- Cloud Firewalls, NodeBalancers
- Managed Databases
- Users and API tokens

**Additional tools required:** `Docker`, `Docker Compose` (or `python3` with venv for standalone)

## Resources

- [Linode Documentation](https://www.linode.com/docs/)
- [OpenTofu Documentation](https://opentofu.org/docs/)
- [Linode API Documentation](https://www.linode.com/docs/api/)
- [s3cmd Documentation](https://s3tools.org/s3cmd)
- [rclone Documentation](https://rclone.org/)
- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)

---

**⚠️ Remember:** Run `./shutdown.sh` after testing to avoid charges.
