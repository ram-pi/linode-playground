# Shared IP for HA Load Balancing

## Overview

This project sets up a highly available (HA) load balancing solution on Linode using the shared IP feature for automatic failover.

**Architecture:**
- **Two frontend nodes** (host_01, host_02): Share a public IP address for failover capability
- **Lelastic**: Manages automatic failover between the two frontend nodes
- **Two backend nodes** (host_03, host_04): Run nginx services on a private VLAN
- **VLAN**: Private network for internal communication between frontend and backend nodes

When the active node fails, the shared IP automatically moves to the standby node, ensuring continuous service availability.

## Architecture

![Architecture Diagram](./drawio.svg)

The infrastructure consists of:
- **Frontend tier**: Two Linode instances (host_01, host_02) sharing a single public IP via Linode's IP sharing feature
- **Backend tier**: Two Linode instances (host_03, host_04) running nginx on a private VLAN (10.10.100.0/24)
- **Failover manager**: Lelastic daemon on each frontend instance handles automatic IP failover
- **Firewall**: Configured to allow internal traffic between frontend and backend nodes

## Deployment

Run the deployment scripts in the following order:

```bash
# 1. Deploy infrastructure (Terraform/OpenTofu)
./start.sh

# 2. Configure frontend nodes and enable failover
./configure-hosts.sh

# 3. Deploy HAProxy load balancers (optional, if using HAProxy)
./deploy-haproxy.sh
```

Each script performs specific tasks:
- `start.sh`: Creates Linode instances, generates SSH keys, and deploys infrastructure
- `configure-hosts.sh`: Applies netplan networking, installs lelastic, and configures IP sharing
- `deploy-haproxy.sh`: Sets up HAProxy load balancing on frontend nodes (if needed)

## Testing Failover

To test the automatic failover functionality:

```bash
# 1. Get the shared IP address
SHARED_IP=$(tofu output -raw host_01_public_ip)

# 2. Verify the service is working
curl http://${SHARED_IP}:80

# 3. Shutdown the master node (host_01)
lin linodes shutdown <host_01_ID>

# 4. Wait a few seconds for failover to occur, then verify service still works
curl http://${SHARED_IP}:80

# 5. Look for HAProxy Stats
open "http://${SHARED_IP}:8404/stats"
```

The shared IP will automatically move to host_02 within seconds, and the service should remain available throughout the failover process.

## References

- [Linode IP Sharing Documentation](https://techdocs.akamai.com/cloud-computing/docs/managing-ip-addresses-on-a-compute-instance#ip-sharing)
- [Configure Failover](https://techdocs.akamai.com/cloud-computing/docs/configure-failover-on-a-compute-instance)
- [Lelastic Project](https://github.com/linode/lelastic)
- [HAProxy Documentation](http://www.haproxy.org/)

## Gotchas

- Network helper has to be disabled for IP sharing to work.
- When network helper is disabled, VLAN won't be automatically configured. You need to manually add the VLAN interface (eth1) configuration to netplan.
- lelastic has be configured manually.
