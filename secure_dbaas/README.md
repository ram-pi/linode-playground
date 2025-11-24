# Secure DBaaS with Bastion Host

Secure database infrastructure setup on Linode using VPC networking and a bastion host for controlled access. This architecture demonstrates best practices for deploying database services with enhanced security through network isolation and controlled access points.

## Architecture

![diagram](drawio.svg)

## Features

- **Bastion Host**: Secure jump server for accessing private database infrastructure
- **Cloud Firewall**: IP-based access control allowing only your IP and VPC traffic
- **SSH Key Authentication**: Automated SSH key pair generation for secure access
- **Cross-platform Support**: Works on both Windows and Unix-like systems

## Prerequisites

Before running this project, you need:

1. **Linode API Token**: Export it as an environment variable:
   ```bash
   export LINODE_TOKEN='your-token-here'
   ```

2. **Required Tools**:
   - [OpenTofu](https://opentofu.org/) v1.8.0+ or Terraform
   - SSH client for connecting to the bastion host

## Quick Start

1. **Set your Linode API token:**
   ```bash
   export LINODE_TOKEN='your-token-here'
   ```

2. **Deploy the infrastructure:**
   ```bash
   ./start.sh
   ```

   The script will:
   - Initialize OpenTofu
   - Plan and apply the infrastructure
   - Wait for cloud-init to complete
   - Display SSH connection command

3. **Connect to the bastion host:**
   ```bash
   ssh -i /tmp/id_rsa root@<bastion-ip>
   ```

   Or use the output command:
   ```bash
   tofu output -raw ssh_command
   ```

4. **Clean up when done:**
   ```bash
   ./shutdown.sh
   ```

## Configuration

### Region
The infrastructure is deployed in the `it-mil` (Milan, Italy) region. To change the region, modify the `region` variable in `main.tf`:

```hcl
locals {
  region = "it-mil"  # Change to your preferred region
}
```

### Firewall Rules

The Cloud Firewall is configured to allow:
- **Your IP**: All TCP/UDP/ICMP traffic from your public IP
- **Private IP Range**: All traffic within the private subnet (192.168.128.0/17)
- **Default**: Drop all other inbound traffic

Your public IP is automatically detected using `https://ipv4.icanhazip.com`.

### SSH Keys

SSH key pairs are automatically generated and stored in:
- **Unix/Linux/macOS**: `/tmp/id_rsa` and `/tmp/id_rsa.pub`
- **Windows**: `$env:TEMP/id_rsa` and `$env:TEMP/id_rsa.pub`

The private key is created with `0600` permissions for security.

## What Gets Deployed

1. **Cloud Firewall**: IP-based access control with rules for your IP and VPC traffic
2. **Bastion Host**: Ubuntu 24.04 instance (g6-nanode-1) with:
   - Public interface for external access
   - Private IP (192.168.128.x) for internal communication
   - SSH key authentication
   - Cloud-init configuration
3. **SSH Key Pair**: Auto-generated RSA 4096-bit keys

## Outputs

After deployment, the following outputs are available:

- **ssh_command**: Complete SSH command to connect to the bastion host

View outputs:
```bash
tofu output ssh_command
```

## Common Use Cases

### Accessing Private Databases
Use the bastion host to connect to databases in the private subnet:
```bash
# SSH to bastion
ssh -i /tmp/id_rsa root@<bastion-ip>

# From bastion, connect to private database
mysql -h 192.168.128.x -u user -p
```

### SSH Tunneling
Create an SSH tunnel for database access:
```bash
ssh -i /tmp/id_rsa -L 3306:192.168.128.x:3306 root@<bastion-ip>
```

Then connect locally:
```bash
mysql -h 127.0.0.1 -P 3306 -u user -p
```

### File Transfer
Transfer files through the bastion:
```bash
scp -i /tmp/id_rsa file.sql root@<bastion-ip>:/tmp/
```

## Troubleshooting

**Cannot connect to bastion host**
- Verify your IP hasn't changed: `curl https://ipv4.icanhazip.com`
- Check firewall rules: `tofu state show linode_firewall.allow-my-ip`
- Ensure SSH key permissions: `chmod 600 /tmp/id_rsa`

**Cloud-init not completing**
- Wait a few more minutes for cloud-init to finish
- Check cloud-init logs via LISH console
- Verify the cloud-init script exists in `scripts/` directory

**Permission denied (publickey)**
- Verify you're using the correct key: `/tmp/id_rsa`
- Check key was properly generated: `ls -la /tmp/id_rsa*`
- Ensure the bastion instance completed provisioning

## Resources

- [Linode VPC Documentation](https://www.linode.com/docs/products/networking/vpc/)
- [Cloud Firewall Documentation](https://www.linode.com/docs/products/networking/cloud-firewall/)
- [OpenTofu Documentation](https://opentofu.org/docs/)
- [Bastion Host Best Practices](https://www.linode.com/docs/guides/use-a-bastion-host/)

---

**⚠️ Remember:** Run `./shutdown.sh` after testing to avoid unnecessary charges.
