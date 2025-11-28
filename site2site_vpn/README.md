# Site-to-Site VPN with WireGuard

Multi-region site-to-site VPN setup using WireGuard, connecting two isolated networks across different Linode datacenters. Infrastructure is provisioned with OpenTofu and VPN configuration is automated with Ansible.

## Architecture

![diagram](drawio.svg)

## Overview

This project creates:
- **2 Sites** in different regions (Milan & Paris)
- **2 Gateway VMs** running WireGuard for encrypted tunneling
- **2 Host VMs** in isolated VLANs, accessible only through the VPN
- **Site-to-Site connectivity** allowing hosts to communicate across regions

## Components

### Infrastructure (OpenTofu)
- **Site 1** (Milan): Gateway + Host on VLAN (10.10.1.0/24)
- **Site 2** (Paris): Gateway + Host on VLAN (10.10.2.0/24)
- **Cloud Firewalls**: Gateway allows your IP + internal traffic, Hosts allow internal only
- **VLAN networking**: Private Layer 2 connectivity within each site

### VPN Configuration (Ansible)
- **WireGuard tunnel** between gateways
- **Automated key generation** and distribution
- **Route configuration** for cross-site communication
- **Host network setup** to use gateway as default route to remote site

## Prerequisites

- **Linode API Token** with read/write permissions
- **OpenTofu** v1.8.0+ or Terraform
- **Ansible** for VPN configuration
- **SSH client** for accessing instances

## Quick Start

1. **Set your Linode API token:**
   ```bash
   export LINODE_TOKEN='your-token-here'
   ```

2. **Provision infrastructure:**
   ```bash
   ./start.sh
   ```

   This will provision:
   - 4 VMs across 2 regions
   - Cloud Firewalls and VLANs
   - SSH keys for access

3. **Configure VPN and routing:**
   ```bash
   ansible-playbook -i vpn-setup/hosts.ini vpn-setup/site-to-site.yaml
   ```

   This Ansible playbook will:
   - Generate WireGuard keys
   - Install and configure WireGuard on gateways
   - Set up the site-to-site VPN tunnel
   - Configure routing on host VMs

4. **Test connectivity:**
   ```bash
   # SSH to Site 1 host
   ssh -o ProxyCommand="ssh -W %h:%p -i /tmp/id_rsa root@<gateway-1-external-ip>" -i /tmp/id_rsa root@<host-1-internal-ip>

   # Ping Site 2 host through the VPN tunnel
   ping 10.10.2.3
   ```

5. **Clean up:**
   ```bash
   ./shutdown.sh
   ```

## Network Details

### Site 1 (Milan)
- **Gateway**: 10.10.1.2 (public IP + VLAN)
- **Host**: 10.10.1.3 (VLAN only, no public IP)
- **WireGuard VPN IP**: 192.168.100.1

### Site 2 (Paris)
- **Gateway**: 10.10.2.2 (public IP + VLAN)
- **Host**: 10.10.2.3 (VLAN only, no public IP)
- **WireGuard VPN IP**: 192.168.100.2

### Traffic Flow
```
Host 1 (10.10.1.3)
  → Gateway 1 (10.10.1.2)
  → WireGuard Tunnel
  → Gateway 2 (10.10.2.2)
  → Host 2 (10.10.2.3)
```

## Project Structure

```
site2site_vpn/
├── main.tf              # Region configuration and data sources
├── network.tf           # VPC and VLAN configuration
├── compute.tf           # Gateway and host instances
├── firewall.tf          # Cloud Firewall rules
├── ssh.tf               # SSH key generation
├── outputs.tf           # Ansible inventory and SSH commands
├── providers.tf         # OpenTofu provider configuration
├── start.sh             # Deployment script
├── shutdown.sh          # Cleanup script
├── scripts/
│   └── cloud-init.yaml  # VM initialization
└── vpn-setup/
    ├── site-to-site.yaml    # Ansible playbook
    ├── hosts.ini            # Ansible inventory (auto-generated)
    └── templates/
        ├── wg0.conf.j2      # WireGuard configuration template
        └── route.yaml.j2    # Netplan routing template
```

## How It Works

### 1. Infrastructure Provisioning (OpenTofu)
- Creates 4 VMs across 2 regions
- Configures VLANs for isolated networks
- Sets up Cloud Firewalls:
  - Gateways: Allow your IP + internal traffic
  - Hosts: Allow internal traffic only (no public access)
- Generates SSH keys for access

### 2. VPN Configuration (Ansible)
The `site-to-site.yaml` playbook:
1. **Generates WireGuard keys** locally for both gateways
2. **Configures gateway VMs**:
   - Installs WireGuard
   - Creates `/etc/wireguard/wg0.conf` with peer details
   - Starts WireGuard service
3. **Configures host VMs**:
   - Sets up networkd routing via gateway
      - Adds routes to remote site subnet

### 3. Connectivity
Once configured, hosts can communicate across sites:
- Host 1 can ping/SSH to Host 2 at 10.10.2.3
- Host 2 can ping/SSH to Host 1 at 10.10.1.3
- All traffic is encrypted through WireGuard tunnel

## Use Cases

- **Multi-region private networking** without exposing services publicly
- **Secure branch office connectivity** across different datacenters
- **Hybrid cloud setups** with isolated networks
- **Testing distributed applications** across geographic locations

## Security Features

- **Encrypted VPN tunnel** using WireGuard
- **No public IPs on hosts** - only accessible through VPN
- **Firewall rules** restrict access to your IP and internal networks
- **SSH key authentication** only
- **Network isolation** using VLANs

## Gotchas

### Network Helper and Custom Netplan

**Important:** This project uses Linode's Network Helper to manage networking configuration automatically.

Network Helper simplifies network configuration by automatically generating the necessary files on boot. However, if you need custom netplan configurations (such as advanced routing or VPN gateway setups), you have two options:

1. **Use Network Helper with `networkd` (current approach):** Configure routes via `networkd` configuration files in `/etc/systemd/network/`. This works alongside Network Helper without conflicts.

2. **Disable Network Helper and use custom netplan:** For full control over netplan configuration, you can disable Network Helper and manage all network configuration manually. This requires configuring interfaces, IP addresses, and routes entirely through netplan.

For more information on Network Helper and configuration options, see: [Linode Network Helper Documentation](https://techdocs.akamai.com/cloud-computing/docs/automatically-configure-networking)

This project uses the first approach (`networkd` routes) to maintain compatibility with Network Helper while still achieving site-to-site VPN connectivity.

## Troubleshooting

**VPN tunnel not working:**
```bash
# On gateway, check WireGuard status
wg show

# Check if tunnel is up
ip addr show wg0
```

**Cannot ping remote host:**
```bash
# On host, check routes
ip route | grep 10.10
```

**Ansible fails to connect:**
- Verify SSH key path: `/tmp/id_rsa`
- Check `vpn-setup/hosts.ini` has correct IPs
- Ensure gateways are accessible from your IP

## Resources

- [WireGuard Documentation](https://www.wireguard.com/)
- [Linode VLAN Documentation](https://www.linode.com/docs/products/networking/vlans/)
- [Ansible Documentation](https://docs.ansible.com/)
- [Linode Network Helper Documentation](https://techdocs.akamai.com/cloud-computing/docs/automatically-configure-networking)

---

**⚠️ Remember:** Run `./shutdown.sh` after testing to avoid charges.
