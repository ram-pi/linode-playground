# Active/Passive Dual-Stack (VPC + VLAN) VIP with FRR/BGP

## Overview

This demo creates three Linode VMs:

- VLAN interface on each node in `172.16.1.0/24`
- VPC interface on each node in `10.10.100.0/24` with 1:1 NAT
- No public IP sharing: failover is centered on the VLAN VIP only
- FRR with BGP signaling between both nodes over VLAN
- VLAN VIP (`172.16.1.100/32`) for private-path gateway use cases
- A third test VM on VLAN to validate VIP reachability and failover behavior

This is a more advanced alternative to `lelastic`, aligned with Akamai/Linode FRR failover guidance.

## Topology

Diagram source: `mermaid.mmd`

- `host_01`:
  - Public interface (management only)
  - VPC IP: `10.10.100.11` + NAT 1:1
  - VLAN IP: `172.16.1.11/24`
  - BGP role: `primary`
- `host_02`:
  - Public interface
  - VPC IP: `10.10.100.12` + NAT 1:1
  - VLAN IP: `172.16.1.12/24`
  - BGP role: `secondary`
- Shared VLAN VIP:
  - `172.16.1.100/32`
- `host_03` (test client):
  - Public interface (management only)
  - VLAN IP: `172.16.1.13/24`
  - Purpose: send traffic to VLAN VIP for testing

## Files

- `start.sh`: Deploy infrastructure with OpenTofu
- `configure-hosts.sh`: Configure FRR/BGP via Ansible
- `shutdown.sh`: Destroy resources and clean local artifacts
- `ansible/playbook.yml`: Installs and configures FRR
- `ansible/templates/frr.conf.j2`: FRR BGP template
- `ansible/templates/keepalived.conf.j2`: optional keepalived health-check config
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

Optional keepalived integration:

```bash
ENABLE_KEEPALIVED=true ./configure-hosts.sh
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

1. Confirm BGP route on both nodes with `vtysh`.
2. Stop FRR on `host_01`.
3. Validate continued reachability and route preference shift to `host_02`.
4. Start FRR again on `host_01`.

## Teardown

```bash
./shutdown.sh
```

## Production Considerations

This example is a PoC. For production, implement the sections below.

### Where to run validation

- Run `./scripts/validate-failover.sh` from your laptop in this folder.
- Use `host_03` as a synthetic client to test traffic to the VLAN VIP.
- Keep orchestration local so OpenTofu outputs and SSH access stay in one place.

### Service-aware failover

Service-aware failover means route and VIP decisions are driven by application health, not only by host or BGP daemon state.

Control loop:

1. Observe: collect health signals from app, host, and network.
2. Decide: evaluate policy (for example quorum and hold-down).
3. Act: add or remove VIP ownership and advertise or withdraw routes.

Recommended health signals:

- Application endpoint check (for example `/healthz` with timeout and expected response).
- Local dependency checks (DB port, cache, upstream API, disk space).
- FRR/BGP session state and route installation state.
- Host health (CPU saturation, memory pressure, interface errors).

Action policy:

- If app is unhealthy but host is alive, withdraw route advertisement and remove VIP ownership.
- If app is healthy and BGP is stable, advertise route and own VIP.
- If only one signal is degraded, do not flap immediately; require sustained failure before demotion.

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

### BFD and tighter convergence tuning

Default BGP timers can make failover slower than required. BFD improves neighbor failure detection speed.

What changes with BFD:

- Faster detection of peer/path failure.
- Faster route withdrawal and reconvergence.
- Better control of failover SLOs.

Tradeoff:

- Aggressive timers improve speed but can increase false positives during jitter or packet loss.

Safe rollout sequence:

1. Baseline current convergence with repeated failover tests.
2. Enable BFD conservatively and validate stability.
3. Tighten timers gradually while tracking flap rate.
4. Keep rollback values documented and easy to apply.

### Monitoring and alerting blueprint

Collect at least these signal groups:

- Reachability: probe VIP from `host_03` and an external vantage point.
- Routing health: BGP session up/down, route presence, route preference changes.
- Ownership state: which node currently owns `172.16.1.100`.
- Service state: endpoint latency, error rate, success ratio.
- Host state: CPU, memory, disk, interface packet drops/errors.

Suggested stack:

- Prometheus + Alertmanager + Grafana.
- Node Exporter on hosts for system metrics.
- Blackbox probes for VIP endpoint checks.
- FRR metrics via exporter or scripted `vtysh` JSON collection.

Minimum dashboards:

1. VIP reachability and latency over time.
2. BGP sessions and route state timeline.
3. VIP ownership transitions and failover events.
4. App health and dependency checks on both nodes.

Minimum alerts:

1. Critical: VIP unreachable from all probes.
2. Critical: both BGP sessions down.
3. Warning: unexpected ownership oscillation (flapping).
4. Warning: elevated app latency or error rate on active node.

### Security and resilience hardening

- Harden host access (MFA, bastion, restricted ingress).
- Create backup/restore and DR runbooks.
- Use multi-AZ or multi-region architecture for real disaster recovery.

## References

- https://techdocs.akamai.com/cloud-computing/docs/configuring-ip-failover-over-bgp-using-frr-advanced
- https://techdocs.akamai.com/cloud-computing/docs/configure-failover-on-a-compute-instance
