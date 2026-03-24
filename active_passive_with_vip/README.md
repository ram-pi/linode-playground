# Active/Passive Dual-Stack (VPC + VLAN) VIP with Keepalived VRRP

## Overview

This demo creates three Linode VMs:

- VLAN interface on each node in `172.16.1.0/24`
- VPC interface on each node in `10.10.100.0/24` with 1:1 NAT
- No public IP sharing: failover is centered on the VLAN VIP only
- Keepalived VRRP between both nodes over VLAN
- VLAN VIP (`172.16.1.100/32`) for private-path gateway use cases
- A third test VM on VLAN to validate VIP reachability and failover behavior

This design is intentionally VLAN-local. It does not rely on FRR/BGP for VIP ownership.

## Topology

See `mermaid.mmd` for the current Keepalived VRRP topology and failover sequence.

## Files

- `start.sh`: Deploy infrastructure with OpenTofu
- `configure-hosts.sh`: Configure Keepalived via Ansible
- `shutdown.sh`: Destroy resources and clean local artifacts
- `ansible/playbook.yml`: Installs and configures Keepalived
- `ansible/templates/keepalived.conf.j2`: Keepalived VRRP template
- `scripts/validate-failover.sh`: automated validation flow

## Prerequisites

- `LINODE_TOKEN` exported
- `tofu` installed
- `ansible-playbook` installed

## Deploy

Run in this order:

```bash
./start.sh
./configure-hosts.sh
```

Optional service-aware health check:

```bash
HEALTHCHECK_URL=http://127.0.0.1:8080/healthz ./configure-hosts.sh
```

## Validate Failover

Get test commands:

```bash
tofu output -raw test_commands
```

Run scripted validation:

```bash
./scripts/validate-failover.sh
```

Typical validation flow:

1. Confirm Keepalived is active on both nodes.
2. Confirm `host_01` owns the VIP.
3. Stop Keepalived on `host_01`.
4. Validate VIP moves to `host_02` and remains reachable.
5. Start Keepalived again on `host_01`.

## Teardown

```bash
./shutdown.sh
```

## Production Considerations

This example is a PoC. For production, implement the sections below.

### Service-aware failover

Keepalived tracks a local health script. By default it validates the VLAN interface and local VLAN IP.

To make failover service-aware, set `healthcheck_url` in the Ansible playbook variables or inventory to a local endpoint such as `http://127.0.0.1:8080/healthz`.

### Make failover more dynamic

Use these controls to avoid brittle active/passive behavior:

1. Multi-signal scoring: require N of M checks to pass before ownership.
2. Hysteresis: use separate fail and recover thresholds.
3. Hold-down timers: delay demotion or promotion until condition persists.
4. Preempt delay: after recovery, wait before taking ownership back.
5. Graceful drain: stop new flows first, then demote VIP/route.
6. Staged recovery gates: app healthy, then dependencies healthy, then route advertise.

Practical example policy:

1. Demote when 3 consecutive app checks fail over 15s.
2. Promote only after 12 consecutive successful checks over 60s.
3. Block failback for 180s after a demotion event.

### Convergence tuning

The default VRRP interval is 1 second with script checks every 2 seconds.

Tune these in `ansible/playbook.yml` and `ansible/templates/keepalived.conf.j2`:

- `vrrp_advert_int`
- `fall`/`rise` in `vrrp_script`
- `vrrp_priority_primary` and `vrrp_priority_secondary`

### Monitoring and alerting blueprint

Collect at least these signal groups:

- Reachability: probe VIP from `host_03` and an external vantage point.
- Ownership state: which node currently owns `172.16.1.100`.
- Service state: endpoint latency, error rate, success ratio.
- Host state: CPU, memory, disk, interface packet drops/errors.

Suggested stack:

- Prometheus + Alertmanager + Grafana.
- Node Exporter on hosts for system metrics.
- Blackbox probes for VIP endpoint checks.
- Keepalived state collection via journal scraping or scripted `ip`/`systemctl` probes.

Minimum dashboards:

1. VIP reachability and latency over time.
2. Keepalived state timeline.
3. VIP ownership transitions and failover events.
4. App health and dependency checks on both nodes.

Minimum alerts:

1. Critical: VIP unreachable from all probes.
2. Critical: keepalived inactive on both failover nodes.
3. Warning: unexpected ownership oscillation (flapping).
4. Warning: elevated app latency or error rate on active node.

### Security and resilience hardening

- Create backup/restore and DR runbooks.

## References

- https://techdocs.akamai.com/cloud-computing/docs/configure-failover-on-a-compute-instance
