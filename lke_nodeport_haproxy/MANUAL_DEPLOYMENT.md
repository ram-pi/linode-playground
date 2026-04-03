# Manual Deployment Runbook

This document covers **Phase 2**: deploy the hello NodePort service on LKE and configure HAProxy to load-balance to LKE nodes.

## Prerequisites

| Tool | Install |
|------|---------|
| `kubectl` | `brew install kubectl` |
| `tofu` | already used in Phase 1 |
| `wrk` | build from source (see Step 5) |
| `hatop` | `pip3 install hatop` |
| `jq` | `brew install jq` |

---

## Step 1 — Export infrastructure outputs

Run from `lke_nodeport_haproxy/` after `./start.sh` finishes.

```bash
# kubeconfig
tofu output -raw lke_kubeconfig > kubeconfig
export KUBECONFIG=$PWD/kubeconfig

# endpoints
export PROXY_IP=$(tofu output -raw proxy_public_ip | tr -d '\r')
export CLIENT_IP=$(tofu output -raw client_public_ip)
export NODEPORT=$(tofu output -raw nodeport_http)

# ssh helper
export SSH_KEY=$(tofu output -raw ssh_command_proxy | awk '{for (i = 1; i <= NF; i++) if ($i == "-i") print $(i + 1)}')
export PROXY_SSH_CMD_RAW=$(tofu output -raw ssh_command_proxy | tr -d '\r')

echo "Proxy IP: ${PROXY_IP}"
echo "Client IP: ${CLIENT_IP}"
echo "NodePort: ${NODEPORT}"
```

Verify cluster readiness:

```bash
kubectl get nodes -o wide
# Expected: all nodes are Ready
```

---

## Step 2 — Deploy hello NodePort service

```bash
kubectl apply -f configs/01-hello-nodeport.yaml

# Wait for the Deployment to become ready
kubectl -n hello rollout status deploy/hello-deploy
kubectl -n hello get pods -o wide
kubectl -n hello get svc hello-nodeport
# Expected: NodePort 32080/TCP
```

Complex workload variants:

```bash
# Cluster policy (baseline complex)
kubectl apply -f configs/02-hello-complex-nodeport.yaml

# Local policy (option 3 test)
kubectl apply -f configs/03-hello-complex-nodeport-local.yaml

kubectl -n hello-complex rollout status deploy/hello-complex-deploy
kubectl -n hello-complex get svc hello-complex-nodeport -o wide
```

---

## Step 3 — Install Cloud Firewall CRDs

```bash
helm repo add cloud-firewall-controller https://linode.github.io/cloud-firewall-controller
helm repo update

helm upgrade --install cloud-firewall-crd \
  cloud-firewall-controller/cloud-firewall-crd \
  --wait --timeout 5m
```

Verify:

```bash
kubectl get crd | grep firewall
# Expected: one or more CRD entries
```

---

## Step 4 — Install Cloud Firewall Controller

```bash
helm upgrade --install cloud-firewall \
  cloud-firewall-controller/cloud-firewall-controller \
  --wait --timeout 5m
```

Verify:

```bash
kubectl get pods -A | grep cloud-firewall
# Expected: cloud-firewall pod in Running state
```

---

## Step 5 — Create custom firewall rule for HAProxy→NodePort

Allow the HAProxy VM to reach all K8s nodes on the NodePort (32080).

```bash
# Export proxy IP if not already set
export PROXY_IP=$(tofu output -raw proxy_public_ip | tr -d '\r')

# Create a patch to add the allow-haproxy rule to the primary firewall
cat > /tmp/firewall-patch.json <<EOF
[
  {
    "op": "add",
    "path": "/spec/ruleset/inbound/-",
    "value": {
      "action": "ACCEPT",
      "addresses": {
        "ipv4": ["${PROXY_IP}/32"]
      },
      "description": "Allow HAProxy to K8s NodePort",
      "label": "allow-haproxy-nodeport",
      "ports": "32080",
      "protocol": "TCP"
    }
  }
]
EOF

# Apply the patch to the primary CloudFirewall
kubectl -n kube-system patch cloudfirewalls primary --type=json --patch-file=/tmp/firewall-patch.json
```

Verify the rule was added:

```bash
kubectl -n kube-system get cloudfirewall primary -o yaml | grep -A 5 "allow-haproxy-nodeport"
```

---

## Step 6 — Build HAProxy backend list from LKE nodes

Get node public IPs and render backend lines:

```bash
# Prefer IPv4-only ExternalIP addresses (filters out IPv6)
NODE_IPS=$(kubectl get nodes -o json | jq -r '.items[].status.addresses[] |
  select(.type=="ExternalIP") |
  select(.address | test("^[0-9]+\\.[0-9]+\\.[0-9]+\\.[0-9]+$")) |
  .address')

echo "$NODE_IPS"
# Expected: one external IP per node
```

Create a local HAProxy config file:

```bash
PROXY_NPROC=$(eval "$PROXY_SSH_CMD_RAW \"nproc\"")

cat > /tmp/haproxy.cfg <<EOF
global
  log /dev/log local0
  log /dev/log local1 notice
  maxconn 500000
  nbthread ${PROXY_NPROC}  # auto-detects vCPU count on the proxy
  #tune.maxaccept 100000
  tune.maxaccept -1
  daemon

  # increase FD limit for haproxy process via systemd (see runbook)
  # unix socket for admin/monitoring (hatop)
  stats socket /var/run/haproxy.sock mode 660 level admin
  stats timeout 2m

defaults
  log global
  mode http
  option dontlog-normal # only log errors
  option dontlognull
  option http-keep-alive
  timeout connect 3s
  timeout client 15s
  timeout server 15s
  maxconn 100000

frontend fe_nodeport
  bind *:80
  default_backend be_lke_nodes
  # lightweight stats endpoint for quick checks (no auth in this demo)
  stats uri /haproxy?stats

frontend stats
    bind *:8404
    stats enable
    stats uri /stats
    stats refresh 5s          # auto-refresh every 5 seconds
    stats show-legends
    stats show-node

backend be_lke_nodes
  balance roundrobin
  # Use a path the demo backends actually serve to avoid false DOWN states.
  option httpchk GET /
  http-check expect status 200
  option forwardfor header X-Forwarded-For
  http-reuse always
EOF

idx=1
while IFS= read -r ip; do
  [ -z "$ip" ] && continue
  echo "  server lke${idx} ${ip}:${NODEPORT} check" >> /tmp/haproxy.cfg
  idx=$((idx + 1))
done <<< "$NODE_IPS"

cat /tmp/haproxy.cfg
```

Apply it to the proxy VM:

```bash
scp -i "$SSH_KEY" /tmp/haproxy.cfg root@${PROXY_IP}:/etc/haproxy/haproxy.cfg
PROXY_SSH_CMD_RAW=$(tofu output -raw ssh_command_proxy | tr -d '\r')
eval "$PROXY_SSH_CMD_RAW \"haproxy -c -f /etc/haproxy/haproxy.cfg && systemctl restart haproxy && systemctl status haproxy --no-pager\""
```

---

## Step 7 — Validate end-to-end behavior

From your local machine:

```bash
# Quick sanity: ensure PROXY_IP is set and contains only IPv4
echo ">${PROXY_IP}<"
if [ -z "${PROXY_IP}" ]; then
  echo "ERROR: PROXY_IP is empty. Re-run the exports from Step 1."
else
  curl -s "http://${PROXY_IP}/"
fi
```

Expected output shape:

```text
hello
client_ip=<your-local-ip-or-forwarded-source>
remote_addr=<proxy-vm-ip>
x_forwarded_for=<client-ip>
```

From the client VM (safe invocation):

```bash
# Build SSH pieces safely from the raw ssh command
CLIENT_SSH_CMD_RAW=$(tofu output -raw ssh_command_client | tr -d '\r')
SSH_KEY_CLIENT=$(echo "$CLIENT_SSH_CMD_RAW" | awk '{for (i=1;i<=NF;i++) if ($i=="-i") print $(i+1)}')
SSH_USER_HOST=$(echo "$CLIENT_SSH_CMD_RAW" | awk '{print $NF}')

# Run a simple curl over SSH
ssh -i "$SSH_KEY_CLIENT" "$SSH_USER_HOST" "curl http://${PROXY_IP}/"
```

Expected output:
- `x_forwarded_for` should match the client VM public IP.
- `client_ip` should match that forwarded IP.

---

## Step 8 — Load test with wrk (recommended)

`wrk` scales much better for high-concurrency tests than `hey`. Use multiple client VMs to share load — the single `client` VM here is useful for small tests but not for 100k QPS alone.

Install `wrk` on each client VM (build from source):

```bash
# on client VM
apt install wrk
```

Run `wrk` from each client. Example: 3 client VMs targeting ~33k RPS each. Tune `-t` (threads) and `-c` (connections) per-client to reach target.

> **Throughput ceiling (Little's Law):** `RPS_max = connections / avg_latency_seconds`. With `-c 1000` and ~33ms backend latency the ceiling is ~30k RPS regardless of proxy or node capacity. Increase `-c` first before scaling infrastructure. Check `CurrConns` in HAProxy `show info` — if it matches your `-c` value, connections are the limit. Check client CPU with `top` during the test — if it is near 100%, the client VM is the limit and you need a second client.

Per-client example (adjust to machine capacity):

```bash
# on each client VM — ramp connections to find the practical ceiling
wrk -t 8  -c 1000  -d 60s --latency http://${PROXY_IP}/   # baseline
wrk -t 8  -c 2000  -d 60s --latency http://${PROXY_IP}/   # 2x connections
wrk -t 12 -c 4000  -d 60s --latency http://${PROXY_IP}/   # push further
```

Aggregate the results across clients to estimate total QPS. Start at low load and ramp up (10k → 50k → 100k), monitor `haproxy` and system metrics.

Suggested small-scale sanity test (single client):

```bash
wrk -t4 -c200 -d30s --latency http://${PROXY_IP}/
```

Note: `wrk` does not have a built-in RPS limiter — use connections and threads to control throughput or run multiple coordinated clients.

### Monitoring HAProxy with hatop

Install `hatop` on a monitoring machine (can be the proxy VM):

```bash
sudo apt install -y hatop
```

Ensure HAProxy exposes a stats socket or stats web page (the example haproxy.cfg below includes a socket). Then run:

```bash
# interactive terminal monitor (connects to the local socket)
sudo hatop -s /var/run/haproxy.sock

# or use the stats web UI at http://${PROXY_IP}/haproxy?stats (configure credentials in haproxy.cfg)
```

If `hatop` cannot connect, you can query the socket manually:

```bash
echo "show stat" | sudo socat unix-connect:/var/run/haproxy.sock stdio
```

Interpretation:
- Increase `-c` until p99 latency and error rates rise sharply.
- The highest stable tier with low errors is your practical operating point.

---

## Troubleshooting

### HAProxy returns 503

- Backends missing or unhealthy.
- Rebuild config and ensure each node IP has `:32080` reachable.

```bash
ssh -i "$SSH_KEY" root@${PROXY_IP} "grep -n 'server lke' /etc/haproxy/haproxy.cfg"
ssh -i "$SSH_KEY" root@${PROXY_IP} "systemctl status haproxy --no-pager"
```

### hello pods are not running or not ready

```bash
kubectl -n hello get pods -o wide
kubectl -n hello describe deployment hello-deploy
```

### Client IP not preserved as expected

- Network-level source IP becomes the proxy VM.
- App-level client identity is carried in `X-Forwarded-For`.
- Confirm header propagation in response body.

---

## Performance tuning for ~100k QPS

Targeting 100k QPS requires multiple dimensions of scaling: more proxy capacity (vertical scaling, horizontal scaling), sufficient backend capacity (more pods or nodes), and OS/network tuning. Below are practical steps and concrete settings to try.

  - Preserve original source IP at TCP layer: keep `externalTrafficPolicy: Local` on the NodePort service and ensure a pod is present on every node (DaemonSet) and scale the cluster with more nodes (increase `lke_node_count`). This avoids SNAT so the app sees node-level source, but you already set `X-Forwarded-For` which is simpler.

 - HAProxy tuning (concrete values for 100k QPS target):
   - Global (`/etc/haproxy/haproxy.cfg` global section):
     ```cfg
     global
       maxconn 500000
       nbthread 32            # set to vCPU count of proxy VM (g7-dedicated-32-16 → 32)
       tune.maxaccept 100000
       daemon
     defaults
       maxconn 200000
       timeout connect 3s
       timeout client 60s
       timeout server 60s
     ```
   - Backend options to reduce backend churn:
     ```cfg
     backend be_lke_nodes
       option httpchk GET /
       http-check expect status 200
       option forwardfor
       http-reuse always
       option http-server-close
     ```

 - OS / kernel tuning on proxy VM (example `/etc/sysctl.d/99-haproxy.conf`):
  ```bash
  net.core.somaxconn = 65535
  net.core.netdev_max_backlog = 300000
  net.ipv4.tcp_max_syn_backlog = 324000
  net.ipv4.tcp_tw_reuse = 1
  net.ipv4.tcp_fin_timeout = 15
  net.ipv4.tcp_max_tw_buckets = 50000
  net.ipv4.ip_local_port_range = 1024 65535
  net.core.rmem_default = 262144
  net.core.rmem_max     = 524288
  net.core.wmem_default = 262144
  net.core.wmem_max     = 524288
  ```
  Apply (copy-paste safe):
  ```bash
  printf '%s
  ' 'net.core.somaxconn = 65535' \
    'net.core.netdev_max_backlog = 300000' \
    'net.ipv4.tcp_max_syn_backlog = 324000' \
    'net.ipv4.tcp_tw_reuse = 1' \
    'net.ipv4.tcp_fin_timeout = 15' \
    'net.ipv4.tcp_max_tw_buckets = 50000' \
    'net.ipv4.ip_local_port_range = 1024 65535' \
    'net.core.rmem_default = 262144' \
    'net.core.rmem_max     = 524288' \
    'net.core.wmem_default = 262144' \
    'net.core.wmem_max     = 524288' | sudo tee /etc/sysctl.d/99-haproxy.conf >/dev/null
  sudo sysctl --system
  ```

 - Increase file descriptor limits for haproxy (systemd unit override):
   ```bash
   sudo mkdir -p /etc/systemd/system/haproxy.service.d
   printf '%s
   ' '[Service]' 'LimitNOFILE=500000' | sudo tee /etc/systemd/system/haproxy.service.d/limits.conf >/dev/null
   sudo systemctl daemon-reload
   sudo systemctl restart haproxy
   ```

 - Observability and validation:
   - Monitor `haproxy` stats via `hatop`, `ss -s`, `netstat -an`, and pod/node metrics (CPU, network). Increase `nbthread` or add proxy nodes if CPU/network saturates.
   - Use multiple `wrk` clients. Example per-client invocation for ~33k RPS: `wrk -t12 -c4000 -d60s --latency http://PROXY_IP/` (adjust `-t`/`-c` per client based on available CPU).

Notes:
- 100k QPS is non-trivial; Start with conservative ramps (10k→50k→100k) and observe errors/latency.
