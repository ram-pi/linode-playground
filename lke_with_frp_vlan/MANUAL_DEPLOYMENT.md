# Manual Deployment Runbook

This document covers **Phase 2**: installing Helm charts and deploying FRP workloads on the LKE cluster provisioned in Phase 1 (`./start.sh`).

## Prerequisites

| Tool | Install |
|------|---------|
| `kubectl` | `brew install kubectl` or [official docs](https://kubernetes.io/docs/tasks/tools/) |
| `helm` | `brew install helm` |
| `envsubst` | included in `gettext` — `brew install gettext` (macOS) or `apt-get install gettext-base` (Ubuntu) |
| `tofu` | already used in Phase 1 |

---

## Step 1 — Export infrastructure outputs

Run these from the `lke_with_frp_vlan/` directory after `./start.sh` completes.

```bash
# Export kubeconfig
tofu output -raw lke_kubeconfig > kubeconfig
export KUBECONFIG=$PWD/kubeconfig

# Verify LKE nodes are Ready before continuing
kubectl get nodes -o wide
# Expected: all nodes in "Ready" state

# Export values needed for chart install and workload config
export FRP_TOKEN=$(tofu output -raw frp_token)
export FRP_SERVER_ADDR=$(tofu output -raw frp_server_vlan_ip)
export FRP_SERVER_PORT=7000         # matches var.frp_bind_port default
export FRP_REMOTE_PORT=8080         # matches var.frp_remote_port default
export VLAN_LABEL=$(tofu output -raw vlan_label)
export VLAN_CIDR=$(tofu output -raw vlan_cidr)
export LINODE_TOKEN=<your-token>    # same token used for tofu apply

echo "FRP server: ${FRP_SERVER_ADDR}:${FRP_SERVER_PORT}"
echo "FRP remote port: ${FRP_REMOTE_PORT}"
echo "VLAN: ${VLAN_LABEL} (${VLAN_CIDR})"
echo "FRP token length: ${#FRP_TOKEN}"
```

Verify frps VM is running:

```bash
SSH_KEY=$(tofu output -raw ssh_command | awk '{for (i = 1; i <= NF; i++) if ($i == "-i") print $(i + 1)}')
FRPS_IP=$(tofu output -raw frp_server_public_ip)
ssh -i "$SSH_KEY" "root@$FRPS_IP" "systemctl status frps"
# Expected: Active: active (running)
```

---

## Step 2 — Create namespaces

```bash
kubectl create namespace lke-vlan-controller --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f configs/00-namespace.yaml   # creates 'frp' namespace
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

## Step 5 — Install lke-vlan-controller

This chart patches each LKE node to add a VLAN interface and **reboots each node**. Allow 5–10 minutes for the node pool to fully recover.

```bash
helm upgrade --install lke-vlan-controller \
  oci://ghcr.io/ram-pi/lke-vlan-controller \
  --namespace lke-vlan-controller \
  --set vlan.name="$VLAN_LABEL" \
  --set vlan.cidr="$VLAN_CIDR" \
  --set linodeToken="$LINODE_TOKEN" \
  --set reboot.enabled=true \
  --set namespace.create=false \
  --timeout 15m
```

Wait for all nodes to reboot and rejoin:

```bash
kubectl get nodes -w
# Wait until all nodes return to Ready

kubectl get nodes -L lke-vlan-controller-status,vlan-ip
# Expected: all nodes show lke-vlan-controller-status=done and a vlan-ip value
```

**Troubleshooting**: If a node stays in NotReady, check the controller logs:

```bash
kubectl -n lke-vlan-controller get pods
CONTROLLER_POD=$(kubectl -n lke-vlan-controller get pods -o name | grep lke-vlan-controller | head -n 1)
kubectl -n lke-vlan-controller logs "$CONTROLLER_POD" --tail=50
```

---

## Step 6 — Deploy dummy nginx

```bash
kubectl apply -f configs/01-nginx.yaml

kubectl -n frp rollout status deployment/dummy-nginx
# Expected: deployment "dummy-nginx" successfully rolled out

kubectl -n frp get pods,svc
```

---

## Step 7 — Apply frpc ConfigMap

> **Proxy routing options**: This step uses **TCP proxies** (one service = one remote port). For multi-service scaling with shared ports and hostname routing, see **Advanced: Multi-service HTTP proxy with hostname routing** below.

The ConfigMap is generated from a template using the values exported in Step 1.

```bash
envsubst < configs/02-frpc-configmap.yaml.tpl | kubectl apply -f -
```

Verify:

```bash
kubectl -n frp get configmap frpc-config -o yaml
# Confirm serverAddr matches FRP_SERVER_ADDR (e.g. 172.20.200.101)
# Confirm auth.token is present and non-empty
```

---

## Step 8 — Deploy frpc

```bash
kubectl apply -f configs/03-frpc-deployment.yaml

kubectl -n frp rollout status deployment/frpc
# Expected: deployment "frpc" successfully rolled out
```

---

## Step 9 — Verify end-to-end tunnel

```bash
# 1. Check frpc connected to frps
kubectl -n frp logs -l app=frpc --tail=20
# Expected lines:
#   [I] [service.go] login to server success, get run id ...
#   [I] [proxy_manager.go] proxy added: [dummy-nginx]
#   [I] [control.go] client login success
# Optional warning during quick restarts/reconnects:
#   [W] ... [dummy-nginx] start error: proxy [dummy-nginx] already exists
# Usually transient when a prior frpc session is still being released by frps.

# 2. Test tunnel from frps VM
FRPS_IP=$(tofu output -raw frp_server_public_ip)
SSH_KEY=$(tofu output -raw ssh_command | awk '{for (i = 1; i <= NF; i++) if ($i == "-i") print $(i + 1)}')
ssh -i "$SSH_KEY" "root@$FRPS_IP" "curl -s http://127.0.0.1:${FRP_REMOTE_PORT} | head -5"
# Expected: nginx welcome page HTML (<h1>Welcome to nginx!</h1>)

# 3. Check FRP admin UI
echo "Admin UI: $(tofu output -raw frp_admin_ui_endpoint)"
echo "Admin credentials: admin / $(tofu output -raw frp_token)"
```

## Step 10 — Load test the FRP tunnel with hey

Install `hey` if needed:

```bash
brew install hey
```

Run a sustained test that targets about 1000 requests per second from your client:

```bash
FRPS_IP=$(tofu output -raw frp_server_public_ip)
hey -z 60s -c 200 -q 5 "http://${FRPS_IP}:${FRP_REMOTE_PORT}/"
```

- `-c 200` keeps 200 requests in flight.
- `-q 5` caps each worker at about 5 requests/sec, so the total target is about 200 x 5 = 1000 RPS.
- Check `Requests/sec` in the output. If it is around 1000 with low error counts and low tail latency, the setup is sustaining about 1000 RPS from that client.

For a stricter test that disables HTTP keep-alive reuse:

```bash
FRPS_IP=$(tofu output -raw frp_server_public_ip)
hey -z 60s -c 200 -q 5 -disable-keepalive "http://${FRPS_IP}:${FRP_REMOTE_PORT}/"
```

---

## Troubleshooting

### frpc logs show "login to server failed"

1. Verify the token matches on both sides:

   ```bash
   tofu output -raw frp_token
   kubectl -n frp get configmap frpc-config -o jsonpath='{.data.frpc\.toml}'
   ```

2. Verify VLAN reachability from a node. Use a debug pod:

   ```bash
   kubectl run net-debug --image=busybox --restart=Never --rm -it -- \
     ping -c 3 $FRP_SERVER_ADDR
   # This uses the pod's default network, not the VLAN
   # For VLAN: check frpc pod logs — it runs with hostNetwork so it shares the node's VLAN interface
   ```

3. Verify VLAN interfaces were assigned to nodes:

   ```bash
   kubectl get nodes -L vlan-ip
   # If vlan-ip column is empty, re-run Step 5
   ```

### frpc pod stuck in Pending

Check events on the pod:

```bash
kubectl -n frp describe pod -l app=frpc
```

Common cause: node hasn't finished rebooting from `lke-vlan-controller` install. Wait until all nodes are `Ready`.

### frpc pod in CrashLoopBackOff

Check logs from the previous container instance:

```bash
kubectl -n frp logs -l app=frpc --previous
```

Common causes:
- Wrong server address or port in ConfigMap (re-check `FRP_SERVER_ADDR`)
- Token mismatch between frps and frpc
- frps is not running on the VM — verify with `$SSH_CMD "systemctl status frps"`
- Entry-point mismatch with `snowdreamtech/frpc` image (`su-exec: -c: No such file or directory`)

If you see `su-exec: -c: No such file or directory`, re-apply the updated deployment manifest:

```bash
kubectl apply -f configs/03-frpc-deployment.yaml
kubectl -n frp rollout restart deployment/frpc
kubectl -n frp rollout status deployment/frpc
kubectl -n frp logs -l app=frpc --tail=20
```

### VLAN interface not showing on nodes

Verify the controller finished its job:

```bash
kubectl -n lke-vlan-controller get pods
CONTROLLER_POD=$(kubectl -n lke-vlan-controller get pods -o name | grep lke-vlan-controller | head -n 1)
kubectl -n lke-vlan-controller logs "$CONTROLLER_POD" --tail=100
```

---

## Re-running after partial failure

All `helm upgrade --install` and `kubectl apply` operations are idempotent — re-run any step independently.

**Reset workloads only** (keep infra and charts, redeploy app):

```bash
kubectl delete -f configs/03-frpc-deployment.yaml --ignore-not-found
kubectl delete -f configs/02-frpc-configmap.yaml.tpl --ignore-not-found 2>/dev/null || \
  kubectl delete configmap frpc-config -n frp --ignore-not-found
kubectl delete -f configs/01-nginx.yaml --ignore-not-found
kubectl delete namespace frp --ignore-not-found

# Wait for namespace to terminate, then re-apply from Step 2
```

**Reset charts** (keep infra, reinstall everything in-cluster):

```bash
helm uninstall lke-vlan-controller -n lke-vlan-controller --ignore-not-found
helm uninstall cloud-firewall --ignore-not-found
helm uninstall cloud-firewall-crc --ignore-not-found
# Then re-run from Step 3
```

---

## Advanced: Multi-service HTTP proxy with hostname routing

By default, this setup uses **TCP proxies** (one service = one remote port). For multiple services, you can use **FRP HTTP proxies** with hostname routing, allowing multiple services on a shared port (80/443).

### Performance comparison

| Proxy Type | Latency Overhead | Throughput | Best For |
|---|---|---|---|
| **TCP** (current) | ~0–5µs (L4 forwarding) | Baseline | Low-latency, non-HTTP, high throughput |
| **HTTP** (hostname) | ~10–50µs (L7 parsing) | ~1–3% lower | Multiple services, DNS-friendly names |

**Real-world impact**: negligible for most workloads (<1ms difference). HTTP adds microseconds of HTTP request parsing but enables scaling beyond single-port-per-service.

### Example: Multi-service HTTP setup

Create services in your cluster (`app1`, `app2`, etc.), then expose via HTTP proxies:

```bash
# Save as: configs/02-frpc-configmap-http.yaml.tpl
# Apply with: envsubst < configs/02-frpc-configmap-http.yaml.tpl | kubectl apply -f -
```

```toml
serverAddr = "${FRP_SERVER_ADDR}"
serverPort = ${FRP_SERVER_PORT}

auth.method = "token"
auth.token  = "${FRP_TOKEN}"

log.to    = "/dev/stdout"
log.level = "info"

[[proxies]]
name           = "app1-http"
type           = "http"
localIP        = "app1.frp.svc.cluster.local"
localPort      = 80
customDomains  = ["app1.frp.example.com"]
# Note: frps must have vhost_http_port = 80 configured

[[proxies]]
name           = "app2-http"
type           = "http"
localIP        = "app2.frp.svc.cluster.local"
localPort      = 80
customDomains  = ["app2.frp.example.com"]

[[proxies]]
name           = "dummy-nginx-tcp"  # Keep TCP proxy as fallback
type           = "tcp"
localIP        = "dummy-nginx.frp.svc.cluster.local"
localPort      = 80
remotePort     = 8080
```

### Switching to HTTP routing

1. **Update frps config** (on the VM):

   ```bash
   SSH_KEY=$(tofu output -raw ssh_command | awk '{for (i = 1; i <= NF; i++) if ($i == "-i") print $(i + 1)}')
   FRPS_IP=$(tofu output -raw frp_server_public_ip)

   ssh -i "$SSH_KEY" "root@$FRPS_IP" << 'EOF'
   cat >> /etc/frp/frps.ini << 'FRPS_EOF'
   vhost_http_port = 80
   vhost_https_port = 443
   FRPS_EOF

   systemctl restart frps
   systemctl status frps
   EOF
   ```

2. **Deploy HTTP proxy config** (in cluster):

   ```bash
   export FRP_SERVER_ADDR=$(tofu output -raw frp_server_vlan_ip)
   export FRP_SERVER_PORT=7000
   export FRP_TOKEN=$(tofu output -raw frp_token)

   envsubst < configs/02-frpc-configmap-http.yaml.tpl | kubectl apply -f -

   kubectl -n frp rollout restart deployment/frpc
   kubectl -n frp rollout status deployment/frpc
   ```

3. **Test with hostname routing**:

   ```bash
   # From frps VM, query by Host header
   SSH_KEY=$(tofu output -raw ssh_command | awk '{for (i = 1; i <= NF; i++) if ($i == "-i") print $(i + 1)}')
   FRPS_IP=$(tofu output -raw frp_server_public_ip)

   ssh -i "$SSH_KEY" "root@$FRPS_IP" << 'EOF'
   curl -H "Host: app1.frp.example.com" http://127.0.0.1:80
   curl -H "Host: app2.frp.example.com" http://127.0.0.1:80
   EOF
   ```

### Hybrid approach (recommended)

Keep TCP proxies for non-HTTP or low-latency, add HTTP proxies for scaling:

- **TCP for**: databases, cache layers, gRPC, binary protocols
- **HTTP for**: web services, REST APIs, microservices

This setup in the ConfigMap above demonstrates both: `app1` and `app2` via HTTP (port 80 shared), `dummy-nginx` via TCP (port 8080 dedicated).
