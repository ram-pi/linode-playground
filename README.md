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

<details>
<summary><b>🔧 <a href="basic/">Basic Multi-Network VM</a></b> - <code>basic/</code></summary>

Basic VM setup demonstrating all three Linode networking types in a single instance. Shows how to configure VPC, VLAN, and Private IP simultaneously for different connectivity patterns.

**Demonstrates:**
- VPC networking with NAT 1:1
- VLAN for Layer 2 connectivity
- Private IP for datacenter-local communication
- Multi-interface configuration
- Cloud-init package installation
- SSH key-based authentication only

</details>

<details>
<summary><b>🔥 <a href="firewall_by_tags/">Firewall Management by Tags</a></b> - <code>firewall_by_tags/</code></summary>

Automated firewall rule management using tag-based assignment. Combines OpenTofu provisioning with Python API automation to dynamically apply firewall rules based on instance tags.

**Demonstrates:**
- Tag-based resource management
- API automation with Python
- Firewall rule propagation timing
- Cloud-init web server setup

</details>

<details>
<summary><b>🔒 <a href="private_vm/">Private VM with NAT Gateway</a></b> - <code>private_vm/</code></summary>

Secure network architecture with a private VM isolated from the internet, accessing external resources through a NAT gateway. Shows VPC design with public/private subnets.

**Demonstrates:**
- VPC with 2 subnets (public + private)
- NAT gateway configuration with iptables
- LISH (Linode Interactive Shell Host) for console access
- VLAN for Layer 2 connectivity
- Multi-interface networking

</details>

<details>
<summary><b>🌐 <a href="static_website/">Static Website with Object Storage</a></b> - <code>static_website/</code></summary>

Deploy a static website using Linode Object Storage with automatic backup synchronization. Demonstrates cloud storage for web hosting with built-in redundancy.

**Demonstrates:**
- Object Storage bucket management
- Static website hosting with S3-compatible storage
- Automatic backup synchronization with rclone
- Bucket policies and public access configuration

**Additional tools required:** `s3cmd`, `rclone`

</details>

<details>
<summary><b>📊 <a href="linode_prometheus_exporter/">Linode Prometheus Exporter</a></b> - <code>linode_prometheus_exporter/</code></summary>

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

You can run `linode_prometheus_exporter` in standalone mode with the command below:

```
docker run --rm -p 9100:9100 -d  -e LINODE_TOKEN=MY_TOKEN  ghcr.io/ram-pi/linode-playground/linode-exporter:v0.0.1
```

</details>

<details>
<summary><b>🔒 <a href="secure_lke/">Secure LKE Cluster</a></b> - <code>secure_lke/</code></summary>

Production-ready Linode Kubernetes Engine (LKE) cluster with enhanced security features including VPC support, Cloud Firewall integration, high-availability control plane, and auto-scaling capabilities.

**Demonstrates:**
- LKE 1.34 with HA control plane
- VPC-native networking with private subnets
- Cloud Firewall integration with IP-based access control
- Cluster auto-scaling (3-6 nodes)
- Dedicated compute instances (g6-dedicated-4)
- Helm chart deployments
- Security hardening scripts

**Additional tools required:** `kubectl`, `helm`

</details>

<details>
<summary><b>🤖 <a href="lke_ai_capabilities/">LKE AI Capabilities</a></b> - <code>lke_ai_capabilities/</code></summary>

LKE Enterprise cluster with App Platform for Linode (APL), featuring AI/ML capabilities through KServe and Knative. Complete platform with integrated tooling, serverless workloads, and ML model serving.

**Demonstrates:**
- App Platform for Linode (APL) deployment
- AI/ML capabilities with KServe and Knative
- Magic DNS with nip.io for automatic DNS resolution
- Object Storage integration (CNPG, Gitea, Harbor, Loki)
- Cloud Firewall Controller for network security
- NLP model training and deployment
- Interactive post-installation workflow

**Additional tools required:** `kubectl`, `helm`, `linode-cli`

</details>

<details>
<summary><b>🗄️ <a href="secure_dbaas/">Secure DBaaS with Bastion Host</a></b> - <code>secure_dbaas/</code></summary>

Secure database infrastructure setup using VPC networking and a bastion host for controlled access. Demonstrates best practices for deploying database services with network isolation and a hardened jump server.

**Demonstrates:**
- VPC isolation
- Bastion host as secure entry point
- Cloud Firewall with IP-based access control
- SSH key-based authentication (password auth disabled)
- PostgreSQL client tools pre-installed on bastion

**Additional tools required:** SSH client

</details>

<details>
<summary><b>🔐 <a href="site2site_vpn/">Site-to-Site VPN with WireGuard</a></b> - <code>site2site_vpn/</code></summary>

Multi-region site-to-site VPN setup using WireGuard, connecting two isolated networks across different Linode datacenters. Infrastructure provisioned with OpenTofu, VPN configured with Ansible.

**Demonstrates:**
- WireGuard VPN tunnel between two sites
- Multi-region deployment (Milan & Paris)
- VLAN networking for isolated hosts
- Ansible automation for VPN configuration
- Custom systemd network configuration routing setup
- Encrypted cross-datacenter connectivity

**Additional tools required:** `ansible`

</details>

<details>
<summary><b>🧹 <a href="utils/">Cleanup Utilities</a></b> - <code>utils/</code></summary>

Collection of cleanup scripts to remove orphaned or unused Linode resources. Includes a master script that automatically discovers and runs all cleanup utilities.

**Demonstrates:**
- Dynamic script discovery and execution
- Linode CLI automation
- Resource cleanup best practices
- Safe deletion workflows with confirmation prompts

**Cleanup scripts:**
- Orphaned Cloud Firewalls
- Unattached Block Storage volumes
- All NodeBalancers
- Private/custom images

**Utility scripts:**
- `list_all_resources.sh` - List all Linode resources in your account

**Additional tools required:** `linode-cli`, `jq`

</details>

<details>
<summary><b>🌐 <a href="http_apis/">HTTP API Examples</a></b> - <code>http_apis/</code></summary>

Collection of `.http` files for testing Linode REST APIs using the VS Code REST Client extension. Provides ready-to-use API request templates for common Linode operations.

**Demonstrates:**
- Direct Linode API interaction
- REST Client usage in VS Code
- API authentication with Bearer tokens

**Additional tools required:** VS Code with [REST Client extension](https://marketplace.visualstudio.com/items?itemName=humao.rest-client)

</details>

<details>
<summary><b>💾 <a href="linode_with_multiple_disks/">Linode with Multiple Disks</a></b> - <code>linode_with_multiple_disks/</code></summary>

Provision a Linode instance with multiple encrypted Block Storage volumes and automated backups to Object Storage. Includes a backup script with rclone, Web UI monitoring, and environment-based configuration.

**Demonstrates:**
- Multiple encrypted Block Storage volumes attached to single instance
- Object Storage for volume backups with lifecycle policies
- Rclone backup automation with Web UI and metrics
- Environment variable-based configuration
- Automated backup scheduling with 30-day retention

**Additional tools required:** `rclone` (auto-installed by backup script)

</details>

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
- [kubectl Documentation](https://kubernetes.io/docs/reference/kubectl/)
- [Helm Documentation](https://helm.sh/docs/)
- [Linode CLI Documentation](https://www.linode.com/docs/products/tools/cli/get-started/)
- [jq Manual](https://stedolan.github.io/jq/manual/)
- [WireGuard Documentation](https://www.wireguard.com/)
- [Ansible Documentation](https://docs.ansible.com/)

---

**⚠️ Remember:** Run `./shutdown.sh` after testing to avoid charges.
