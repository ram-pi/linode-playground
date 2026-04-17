# Manual Deployment Runbook

This document covers **Phase 2** for `lvs-dr-lke` after `./start.sh` has finished.

## Goal

- Deploy a whoami NodePort service on LKE.
- Configure FRR on the LVS DR director VM only.
- Use the director primary public IPv4 as the LVS DR VIP and share it to LKE worker nodes.
- Configure IPVS on the director to forward traffic to LKE nodes using private IPs.

## Prerequisites

| Tool | Install |
|------|---------|
| `kubectl` | `brew install kubectl` |
| `helm` | `brew install helm` |
| `jq` | `brew install jq` |
| `gettext` (`envsubst`) | `brew install gettext` |
| `tofu` | already used in Phase 1 |

---

## Step 1 - Export infrastructure outputs

Run from `lvs-dr-lke/`.

```bash
# kubeconfig
tofu output -raw lke_kubeconfig > kubeconfig
export KUBECONFIG=$PWD/kubeconfig

# core values
export DIRECTOR_IP=$(tofu output -raw director_public_ip | tr -d '\r')
export DIRECTOR_PRIVATE_IP=$(tofu output -raw director_private_ip | tr -d '\r')
# LVS DR VIP is the director primary public IPv4
export LVS_DR_IP="$DIRECTOR_IP"
export NODEPORT=$(tofu output -raw nodeport_http)

# ssh helper
export DIRECTOR_SSH_CMD_RAW=$(tofu output -raw ssh_command_director | tr -d '\r')
export SSH_KEY=$(echo "$DIRECTOR_SSH_CMD_RAW" | awk '{for (i = 1; i <= NF; i++) if ($i == "-i") print $(i + 1)}')

echo "Director IP: ${DIRECTOR_IP}"
echo "Director private IP: ${DIRECTOR_PRIVATE_IP}"
echo "LVS DR IP: ${LVS_DR_IP}"
echo "NodePort: ${NODEPORT}"
```

Verify cluster readiness:

```bash
kubectl get nodes -o wide
# Expected: all nodes are Ready
```

---

## Step 2 - Deploy whoami NodePort service on LKE

The service uses `traefik/whoami` so the response includes source/client metadata.

```bash
kubectl apply -f configs/01-hello-nodeport.yaml
kubectl -n hello rollout status ds/hello-deploy
kubectl -n hello get pods -o wide
kubectl -n hello get svc hello-nodeport
# Expected: NodePort 32080/TCP
```

---

## Step 3 - FRR setup on the LVS DR node only

> This is the required FRR setup step for the director only.

This follows the Akamai advanced FRR guide with:
- `SHARED_IP=${DIRECTOR_IP}` (director public IP)
- `ROLE=primary`
- `DC_ID=27` (`it-mil`)
- `PROTOCOL=ipv4`, `PREFIX=32`

Only the director advertises the VIP. LKE nodes do not run FRR/BGP in this setup.

FRR is preinstalled by cloud-init, but run this to apply the exact BGP config.

```bash
export SHARED_IP="$DIRECTOR_IP"
export ROLE="primary"
export DC_ID="27"
export PREFIX="32"
export PROTOCOL="ipv4"
```

Enable `bgpd`, add the required static loopback route for the primary IP, and write FRR config on director:

```bash
ssh -i "$SSH_KEY" root@${DIRECTOR_IP} <<'EOF'
set -e

# BGP requires an exact /32 match in the routing table to advertise the VIP.
# Since the primary IP is assigned to eth0 with a larger subnet mask (e.g. /24),
# we must add a dummy /32 route to the kernel, otherwise FRR will refuse to send the prefix.
VIP=$(ip -4 addr show dev eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
if ! ip route show | grep -q "$VIP/32"; then
  ip route add $VIP/32 dev lo
fi

cat >/etc/frr/daemons <<'DAEMONS'
# The watchfrr and zebra daemons are always started.
bgpd=yes
ospfd=no
ospf6d=no
ripd=no
ripngd=no
isisd=no
pimd=no
pim6d=no
ldpd=no
nhrpd=no
eigrpd=no
babeld=no
sharpd=no
pbrd=no
pathd=no
bfdd=no
fabricd=no
vrrpd=no
zebra=yes
DAEMONS
EOF
```

```bash
ssh -i "$SSH_KEY" root@${DIRECTOR_IP} "cat >/etc/frr/frr.conf" <<EOF
frr version 8.4.4
frr defaults traditional
hostname lvs-dr-director
service integrated-vtysh-config

router bgp 65001
 bgp router-id ${DIRECTOR_IP}
 no bgp ebgp-requires-policy
 coalesce-time 1000
 bgp bestpath as-path multipath-relax
 neighbor RS peer-group
 neighbor RS remote-as external
 neighbor RS remote-as 65000
 neighbor RS ebgp-multihop 10
 neighbor RS capability extended-nexthop
 neighbor 2600:3c0f:${DC_ID}:34::1 peer-group RS
 neighbor 2600:3c0f:${DC_ID}:34::2 peer-group RS
 neighbor 2600:3c0f:${DC_ID}:34::3 peer-group RS
 neighbor 2600:3c0f:${DC_ID}:34::4 peer-group RS

  address-family ${PROTOCOL} unicast
   network ${SHARED_IP}/${PREFIX} route-map ${ROLE}
   neighbor RS activate
  exit-address-family

route-map primary permit 10
 set community 65000:1

route-map secondary permit 10
 set community 65000:2

ipv6 nht resolve-via-default

ip route ${SHARED_IP}/${PREFIX} lo
EOF
```

```bash
eval "$DIRECTOR_SSH_CMD_RAW \"systemctl enable frr && systemctl restart frr && systemctl status frr --no-pager\""
eval "$DIRECTOR_SSH_CMD_RAW \"vtysh -c 'show bgp summary'\""
```

Ensure the director networking is ready for LVS forwarding and the dummy /32 route exists:

```bash
eval "$DIRECTOR_SSH_CMD_RAW \"ip -4 addr show dev eth0 && ip route show | grep /32\""
```

Apply forwarding settings for DR mode (director only needs forwarding, not ARP suppression):

```bash
eval "$DIRECTOR_SSH_CMD_RAW \"sysctl -w net.ipv4.ip_forward=1\""
```

## Step 4 - IP-sharing on LKE nodes for director primary VIP

> This is the required IP-sharing step.

Run this only after Step 3 is complete and BGP from director is established.
When sharing the director primary IPv4, keep an SSH session open (or use LISH) to avoid lockout during convergence.

Find IDs and share the director primary VIP (`${LVS_DR_IP}`) to each LKE worker node:

```bash
# Director Linode ID (owner of primary VIP)
DIRECTOR_LINODE_ID=$(linode-cli linodes list --json | jq -r --arg ip "$DIRECTOR_IP" '.[] | select(.ipv4[]? == $ip) | .id')

# LKE cluster ID (adjust label if needed)
LKE_CLUSTER_ID=$(linode-cli lke clusters-list --json | jq -r '.[] | select(.label=="lvs-dr-lke") | .id')

# LKE node Linode IDs
NODE_LINODE_IDS=$(linode-cli lke pools-list "$LKE_CLUSTER_ID" --json | jq -r '.[].nodes[].instance_id')

# Share director primary IPv4 to each node
while IFS= read -r node_id; do
  [ -z "$node_id" ] && continue
  linode-cli networking ip-share --linode_id "$node_id" --ips "$LVS_DR_IP"
done <<< "$NODE_LINODE_IDS"

echo "Waiting 3 minutes for BGP routing to converge in the Linode platform..."
sleep 180

# Verify VIP sharing metadata
linode-cli networking ip-view "$LVS_DR_IP"
```

## Step 4.5 - Deploy lke-vlan-controller and VLAN DaemonSet

Because we are using LVS DR, the director and backend nodes must be on the same Layer 2 segment. We use a Linode VLAN to achieve this. The director is already attached to `lvs-vlan` via Terraform, but the LKE worker nodes need to be attached dynamically using the `lke-vlan-controller`.

First, deploy the `lke-vlan-controller` (ensure your API token is available):
```bash
helm upgrade --install lke-vlan-controller \
  oci://ghcr.io/ram-pi/lke-vlan-controller \
  --namespace lke-vlan-controller \
  --create-namespace \
  --set linodeToken="$LINODE_TOKEN" \
  -f configs/lke-vlan-controller.values.yaml
```

Wait for the controller to attach the VLAN to all nodes and assign IPs:
```bash
kubectl -n lke-vlan-controller get pods -l app.kubernetes.io/name=lke-vlan-controller
# Wait until ready, then check node labels for the assigned VLAN IP
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.labels.vlan-ip}{"\n"}{end}'
```

Next, render and apply the DaemonSet that adds the VIP to loopback on each LKE node and sets ARP suppression to prevent MAC address collisions on the VLAN:

```bash
env LVS_VIP="$LVS_DR_IP" envsubst < configs/02-vip-share-daemonset-dr-vlan.yaml.tpl | kubectl apply -f -

kubectl -n kube-system rollout status ds/lvs-vip-share-dr-vlan
kubectl -n kube-system get pods -l app=lvs-vip-share-dr-vlan -o wide
```

Optional verification from one node via debug shell:

```bash
NODE_NAME=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
kubectl debug node/${NODE_NAME} -it --image=alpine -- chroot /host ip -4 addr show lo
# Expected: ${LVS_DR_IP}/32 is present on loopback
```

## Step 5 - Configure IPVS on director with LKE node backends

Collect the LKE node **VLAN IPs** (assigned by the `lke-vlan-controller`):

```bash
NODE_VLAN_IPS=$(kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.labels.vlan-ip}{"\n"}{end}' | cut -d_ -f1)

echo "$NODE_VLAN_IPS"
# Expected: one 10.0.0.x IP per LKE node
```

Build and apply IPVS rules on director.

For LVS DR (`-g`), use the same service port on VIP and real servers (no port translation in DR path).
In this setup, use NodePort on both sides (`${NODEPORT}`):

```bash
IPVS_SCRIPT=$(mktemp)
cat > "$IPVS_SCRIPT" <<EOF
#!/bin/bash
set -e
ipvsadm -C
ipvsadm -A -t ${LVS_DR_IP}:${NODEPORT} -s rr
EOF

while IFS= read -r ip; do
  [ -z "$ip" ] && continue
  echo "ipvsadm -a -t ${LVS_DR_IP}:${NODEPORT} -r ${ip}:${NODEPORT} -g" >> "$IPVS_SCRIPT"
done <<< "$NODE_VLAN_IPS"

echo "ipvsadm -Ln" >> "$IPVS_SCRIPT"
chmod +x "$IPVS_SCRIPT"

scp -i "$SSH_KEY" "$IPVS_SCRIPT" root@${DIRECTOR_IP}:/tmp/configure-ipvs.sh
ssh -i "$SSH_KEY" root@${DIRECTOR_IP} "bash /tmp/configure-ipvs.sh"
```

## Step 6 - Validate end-to-end behavior

From your local client (request VIP on NodePort):

```bash
curl -s "http://${LVS_DR_IP}:${NODEPORT}/" | head -20
```

Expected response contains whoami output.

From director, confirm private-path backend connectivity and force source as director VLAN IP (`10.0.0.1`):

```bash
while IFS= read -r ip; do
  [ -z "$ip" ] && continue
  ssh -n -i "$SSH_KEY" root@${DIRECTOR_IP} "curl -s --connect-timeout 2 --interface 10.0.0.1 \"http://${ip}:${NODEPORT}/\" | head -20"
  echo "---"
done <<< "$NODE_VLAN_IPS"
```

To inspect client details from `whoami`:

```bash
curl -s "http://${LVS_DR_IP}:${NODEPORT}/" | grep -E 'RemoteAddr|X-Forwarded-For|X-Real-Ip|Host'
```

Note: in `whoami` output, lines like `IP: 127.0.0.1` are the pod's own interfaces, not the client address.
The actual source/client is shown in `RemoteAddr`.

Optional repeated checks:

```bash
for i in {1..10}; do
  curl -s "http://${LVS_DR_IP}:${NODEPORT}/" | grep -E 'Hostname|RemoteAddr';
  echo "---";
done
```

---

## Troubleshooting

### VIP not reachable on director

```bash
ssh -i "$SSH_KEY" root@${DIRECTOR_IP} "ip -4 addr show dev eth0 | grep ${LVS_DR_IP}"
ssh -i "$SSH_KEY" root@${DIRECTOR_IP} "ipvsadm -Ln"
```

### No node private IPs discovered

```bash
kubectl get nodes -o wide
kubectl get nodes -o json | jq -r '.items[].status.addresses'
```

### VIP not present on LKE nodes

```bash
kubectl -n kube-system get ds lvs-vip-share
kubectl -n kube-system logs -l app=lvs-vip-share --tail=80
```

### `linode-cli networking ip-share` causes temporary loss of SSH

```bash
echo "Ensure FRR is configured and established first (Step 3)."
echo "Keep a rescue session open, then retry ip-share and wait for BGP convergence."
```

### FRR not running on director

```bash
ssh -i "$SSH_KEY" root@${DIRECTOR_IP} "systemctl status frr --no-pager"
```
