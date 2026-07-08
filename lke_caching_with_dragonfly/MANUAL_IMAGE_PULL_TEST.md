# Manual Image Pull Test

Step-by-step guide to manually benchmark Dragonfly P2P image caching: a **cold pull** (back-to-source from Docker Hub) vs a **hot pull** (served from P2P peers via intra-cluster network).

This guide does not use the automated `scripts/benchmark-image-pull.sh`. Every step is a `kubectl` command you run by hand, so you can inspect intermediate state and troubleshoot.

## Prerequisites

- The LKE cluster is provisioned and Dragonfly is installed (run `./start.sh` first).
- `kubectl` installed locally.
- Kubeconfig available at `./kubeconfig.yaml`.

Set the kubeconfig path once:

```sh
export KUBECONFIG="$PWD/kubeconfig.yaml"
```

## Phase 1: Pre-flight Checks

Before starting, verify the cluster is ready and Dragonfly is correctly configured.

### 1.1 Get node names

```sh
kubectl get nodes -o custom-columns=NAME:.metadata.name --no-headers
```

Pick two distinct nodes for the benchmark. Call them **NODE_0** (cold pull) and **NODE_1** (hot pull):

```sh
NODE_0=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
NODE_1=$(kubectl get nodes -o jsonpath='{.items[1].metadata.name}')
echo "NODE_0 (cold) = $NODE_0"
echo "NODE_1 (hot)  = $NODE_1"
```

### 1.2 Verify Dragonfly pods are running

```sh
kubectl -n dragonfly-system get pods -o wide
```

You should see:
- 1 `dragonfly-manager-*` pod (web UI)
- 1 `dragonfly-scheduler-*` pod (P2P coordination)
- 1 `dragonfly-seed-client-*` pod (back-to-source fetcher)
- N `dragonfly-client-*` pods (one per node, dfdaemon proxy)

### 1.3 Verify dfdaemon proxy is listening on each node

```sh
# On NODE_0
cat <<PODEOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: check-proxy-0
  namespace: default
spec:
  restartPolicy: Never
  nodeSelector:
    kubernetes.io/hostname: ${NODE_0}
  tolerations:
    - operator: Exists
  hostPID: true
  hostNetwork: true
  containers:
    - name: c
      image: docker.io/dragonflyoss/client:v1.4.0
      securityContext:
        privileged: true
      command: ["sh", "-c", "curl -s -o /dev/null -w %{http_code} http://127.0.0.1:4001/v2/ ; echo"]
PODEOF
kubectl wait pod/check-proxy-0 --for=jsonpath='{.status.phase}'=Succeeded --timeout=120s
kubectl logs check-proxy-0
kubectl delete pod check-proxy-0 --ignore-not-found --timeout=30s

# On NODE_1
cat <<PODEOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: check-proxy-1
  namespace: default
spec:
  restartPolicy: Never
  nodeSelector:
    kubernetes.io/hostname: ${NODE_1}
  tolerations:
    - operator: Exists
  hostPID: true
  hostNetwork: true
  containers:
    - name: c
      image: docker.io/dragonflyoss/client:v1.4.0
      securityContext:
        privileged: true
      command: ["sh", "-c", "curl -s -o /dev/null -w %{http_code} http://127.0.0.1:4001/v2/ ; echo"]
PODEOF
kubectl wait pod/check-proxy-1 --for=jsonpath='{.status.phase}'=Succeeded --timeout=120s
kubectl logs check-proxy-1
kubectl delete pod check-proxy-1 --ignore-not-found --timeout=30s
```

Expected output: `401` (dfdaemon is listening and rejecting unauthenticated requests — this is normal).

If you get `000` or the pod hangs, dfdaemon is not running. Check:
```sh
kubectl -n dragonfly-system get pods -l component=client -o wide
kubectl -n dragonfly-system logs <client-pod-on-that-node> -c client --tail=20
```

### 1.4 Verify containerd mirror config on each node

```sh
# On NODE_0
cat <<PODEOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: check-mirror-0
  namespace: default
spec:
  restartPolicy: Never
  nodeSelector:
    kubernetes.io/hostname: ${NODE_0}
  tolerations:
    - operator: Exists
  hostPID: true
  containers:
    - name: c
      image: docker.io/dragonflyoss/client:v1.4.0
      securityContext:
        privileged: true
      command: ["sh", "-c", "nsenter --mount=/proc/1/ns/mnt -- cat /etc/containerd/certs.d/_default/hosts.toml"]
PODEOF
kubectl wait pod/check-mirror-0 --for=jsonpath='{.status.phase}'=Succeeded --timeout=120s
kubectl logs check-mirror-0
kubectl delete pod check-mirror-0 --ignore-not-found --timeout=30s
```

Expected: a `hosts.toml` containing `127.0.0.1:4001` (the Dragonfly proxy). If the file is missing or doesn't reference port 4001, dfinit didn't run — re-run `./scripts/install-dragonfly.sh`.

### 1.5 Check what IP dfdaemon advertises to the scheduler

```sh
kubectl -n dragonfly-system logs dragonfly-scheduler-0 --tail=200 \
  | grep "announce host" \
  | grep -oE 'Id:"[^"]*"|Ip:"[^"]*"' \
  | paste - - \
  | sort -u
```

You will see lines like:

```
Id:"192.168.145.5-lke625618-..."   Ip:"192.168.145.5"    ← private IP (patch applied)
Id:"172.236.22.91-lke625618-..."   Ip:"172.236.22.91"    ← public IP (no patch)
```

If the `patch-dfdaemon-private-ip.sh` script was run (it is called automatically by `install-dragonfly.sh`), you should see private IPs (`192.168.x.x`). If you see public IPs (`172.x.x.x`), the patch was not applied — run it:

```sh
./scripts/patch-dfdaemon-private-ip.sh
```

> **Note:** The patch is a security/isolation best practice — it keeps P2P traffic on the Linode private network instead of the public internet. The A/B test showed no measurable performance difference between private and public IP on LKE (both configurations showed 44-67% P2P improvement), but private IP avoids exposing dfdaemon ports to the public internet.
>
> **Self-healing:** The patch is an init container in the `dragonfly-client` DaemonSet. New nodes automatically get the patch when the DaemonSet schedules a pod on them — the init container detects the private IP at startup. Pod recycles and rolling updates also re-run the init container. No manual re-application is needed when scaling the cluster. The only scenario that requires re-running the script is a `helm upgrade` (which overwrites the DaemonSet spec); `install-dragonfly.sh` handles this automatically.

### 1.6 Verify Cloud Firewall allows P2P traffic

```sh
kubectl -n kube-system get cloudfirewall primary -o jsonpath='{.spec.ruleset.inbound}' | jq .
```

You should see rules for ports `4000`, `4002`, `4005` (TCP) and `4006` (UDP) with source `192.168.128.0/17`. If these are missing, P2P connections between nodes will be dropped. Re-run:

```sh
./scripts/install-cloud-firewall.sh
```

> **Self-healing for new nodes:** The firewall rules use `192.168.128.0/17` (Linode private network CIDR) as the source, which covers all current and future nodes. The Cloud Firewall Controller also watches the `nodes` resource and auto-registers new nodes as firewall devices. **No re-run is needed when adding nodes** — as long as the dfdaemon private IP patch is applied (so P2P traffic uses private IPs within the CIDR). If you skip the private IP patch, dfdaemon advertises public IPs and you must manually add each node's external IP as a `/32` rule.

## Phase 2: Choose an Image and Purge Caches

### 2.1 Choose an image

Pick a Docker Hub image that is **not already present on any node**. Using a fresh image avoids containerd cache issues (see [Troubleshooting](#troubleshooting) below).

Good candidates (250 MB - 1.5 GB):

```sh
IMAGE=docker.io/library/mariadb:11.6     # ~400 MB
# IMAGE=docker.io/library/mongo:7          # ~800 MB
# IMAGE=docker.io/library/rabbitmq:4-management  # ~250 MB
```

### 2.2 Verify the image is not on either node

```sh
```sh
# On NODE_0
cat <<PODEOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: img-check-0
  namespace: default
spec:
  restartPolicy: Never
  nodeSelector:
    kubernetes.io/hostname: ${NODE_0}
  tolerations:
    - operator: Exists
  hostPID: true
  containers:
    - name: c
      image: docker.io/dragonflyoss/client:v1.4.0
      securityContext:
        privileged: true
      command:
        - sh
        - -c
        - |
          nsenter --mount=/proc/1/ns/mnt -- crictl images 2>/dev/null | \\
            grep "\$(echo '${IMAGE}' | sed 's/:.*//' | sed 's|.*/||')" || echo CLEAN
PODEOF
kubectl wait pod/img-check-0 --for=jsonpath='{.status.phase}'=Succeeded --timeout=120s
kubectl logs img-check-0
kubectl delete pod img-check-0 --ignore-not-found --timeout=30s

# On NODE_1
cat <<PODEOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: img-check-1
  namespace: default
spec:
  restartPolicy: Never
  nodeSelector:
    kubernetes.io/hostname: ${NODE_1}
  tolerations:
    - operator: Exists
  hostPID: true
  containers:
    - name: c
      image: docker.io/dragonflyoss/client:v1.4.0
      securityContext:
        privileged: true
      command:
        - sh
        - -c
        - |
          nsenter --mount=/proc/1/ns/mnt -- crictl images 2>/dev/null | \\
            grep "\$(echo '${IMAGE}' | sed 's/:.*//' | sed 's|.*/||')" || echo CLEAN
PODEOF
kubectl wait pod/img-check-1 --for=jsonpath='{.status.phase}'=Succeeded --timeout=120s
kubectl logs img-check-1
kubectl delete pod img-check-1 --ignore-not-found --timeout=30s
```

Both should print `CLEAN`. If either shows the image, remove it:

```sh
# Replace NODE with the node that has the image
NODE=$NODE_0
cat <<PODEOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: rmi-img
  namespace: default
spec:
  restartPolicy: Never
  nodeSelector:
    kubernetes.io/hostname: ${NODE}
  tolerations:
    - operator: Exists
  hostPID: true
  containers:
    - name: c
      image: docker.io/dragonflyoss/client:v1.4.0
      securityContext:
        privileged: true
      command:
        - sh
        - -c
        - |
          nsenter --mount=/proc/1/ns/mnt -- sh -c "crictl rmi '${IMAGE}' 2>&1 | grep -v WARNING; sleep 5; crictl images | grep \"\$(echo '${IMAGE}' | sed 's/:.*//' | sed 's|.*/||')\" || echo GONE"
PODEOF
kubectl wait pod/rmi-img --for=jsonpath='{.status.phase}'=Succeeded --timeout=120s
kubectl logs rmi-img
kubectl delete pod rmi-img --ignore-not-found --timeout=30s
```

> **Important:** `crictl rmi` only removes the image tag. The underlying blob layers may remain in containerd's content store (containerd's garbage collector is lazy). If you reuse an image that was previously pulled, containerd may find the blobs locally and skip downloading through Dragonfly — making the benchmark invalid (both pulls will be ~2s). **Always use a fresh image for a valid cold pull**, or restart containerd on the node (disruptive).

### 2.3 Purge dfdaemon caches on both nodes

> **If you opened a new terminal**, re-set the node variables first:
> ```sh
> export KUBECONFIG="$PWD/kubeconfig.yaml"
> NODE_0=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
> NODE_1=$(kubectl get nodes -o jsonpath='{.items[1].metadata.name}')
> echo "NODE_0=$NODE_0  NODE_1=$NODE_1"
> ```

```sh
for NODE in "$NODE_0" "$NODE_1"; do
  POD=$(kubectl -n dragonfly-system get pods -l component=client \
    -o jsonpath="{.items[?(@.spec.nodeName=='${NODE}')].metadata.name}")
  echo "Purging dfdaemon cache on $NODE (pod: $POD)"
  kubectl -n dragonfly-system exec "$POD" -c client -- \
    sh -c 'rm -rf /var/lib/dragonfly/content/tasks/* /var/lib/dragonfly/content/persistent-tasks/* 2>/dev/null; echo "tasks remaining: $(ls /var/lib/dragonfly/content/tasks/ 2>/dev/null | wc -l)"'
  kubectl -n dragonfly-system delete pod "$POD" --ignore-not-found --timeout=60s
done
```

Wait for new pods to be Running:

```sh
kubectl -n dragonfly-system get pods -l component=client -o wide
```

Wait until all show `1/1 Running` and the AGE column shows recent timestamps (~15-30s). Then wait an additional 10 seconds for dfdaemon to initialize its proxy listener.

## Phase 3: Cold Pull (Back-to-Source)

### 3.1 Create a namespace

```sh
kubectl create namespace benchmark-dragonfly --dry-run=client -o yaml | kubectl apply -f -
```

### 3.2 Create the cold-pull Job on NODE_0

> **If you opened a new terminal**, re-set the variables first:
> ```sh
> export KUBECONFIG="$PWD/kubeconfig.yaml"
> NODE_0=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
> NODE_1=$(kubectl get nodes -o jsonpath='{.items[1].metadata.name}')
> IMAGE=docker.io/library/mariadb:11.6
> echo "NODE_0=$NODE_0  NODE_1=$NODE_1  IMAGE=$IMAGE"
> ```

```sh
cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: cold-pull
  namespace: benchmark-dragonfly
spec:
  backoffLimit: 0
  template:
    spec:
      restartPolicy: Never
      nodeSelector:
        kubernetes.io/hostname: ${NODE_0}
      tolerations:
        - operator: Exists
      containers:
        - name: bench
          image: ${IMAGE}
          imagePullPolicy: Always
          command: ["true"]
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 200m
              memory: 256Mi
EOF
```

### 3.3 Watch the pull

```sh
# Get the pod name
COLD_POD=$(kubectl -n benchmark-dragonfly get pods -l job-name=cold-pull -o jsonpath='{.items[0].metadata.name}')
echo "Cold pull pod: $COLD_POD"

# Watch events (in a separate terminal, or poll)
kubectl -n benchmark-dragonfly get events --field-selector involvedObject.name=${COLD_POD} --sort-by=.firstTimestamp
```

### 3.4 Wait for completion

```sh
kubectl -n benchmark-dragonfly wait job/cold-pull --for=condition=Complete --timeout=60m
```

### 3.5 Extract the pull timing

```sh
COLD_POD=$(kubectl -n benchmark-dragonfly get pods -l job-name=cold-pull -o jsonpath='{.items[0].metadata.name}')

T_PULLING=$(kubectl -n benchmark-dragonfly get events \
  --field-selector involvedObject.name=${COLD_POD},reason=Pulling \
  -o jsonpath='{.items[0].firstTimestamp}')
T_PULLED=$(kubectl -n benchmark-dragonfly get events \
  --field-selector involvedObject.name=${COLD_POD},reason=Pulled \
  -o jsonpath='{.items[0].firstTimestamp}')

echo "Cold pull:"
echo "  Pulling: $T_PULLING"
echo "  Pulled:  $T_PULLED"
COLD_SECONDS=$(($(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$T_PULLED" "+%s") - $(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$T_PULLING" "+%s")))
echo "  Duration: ${COLD_SECONDS}s"
```

> **Linux note:** If you are on Linux, replace `date -j -f` with `date -d`:
> ```sh
> COLD_SECONDS=$(($(date -d "$T_PULLED" "+%s") - $(date -d "$T_PULLING" "+%s")))
> ```

## Phase 4: Hot Pull (P2P)

### 4.1 Create the hot-pull Job on NODE_1

```sh
cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: hot-pull
  namespace: benchmark-dragonfly
spec:
  backoffLimit: 0
  template:
    spec:
      restartPolicy: Never
      nodeSelector:
        kubernetes.io/hostname: ${NODE_1}
      tolerations:
        - operator: Exists
      containers:
        - name: bench
          image: ${IMAGE}
          imagePullPolicy: Always
          command: ["true"]
          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 200m
              memory: 256Mi
EOF
```

### 4.2 Watch and wait

```sh
HOT_POD=$(kubectl -n benchmark-dragonfly get pods -l job-name=hot-pull -o jsonpath='{.items[0].metadata.name}')
echo "Hot pull pod: $HOT_POD"

kubectl -n benchmark-dragonfly get events --field-selector involvedObject.name=${HOT_POD} --sort-by=.firstTimestamp

kubectl -n benchmark-dragonfly wait job/hot-pull --for=condition=Complete --timeout=60m
```

### 4.3 Extract the pull timing

```sh
HOT_POD=$(kubectl -n benchmark-dragonfly get pods -l job-name=hot-pull -o jsonpath='{.items[0].metadata.name}')

T_PULLING=$(kubectl -n benchmark-dragonfly get events \
  --field-selector involvedObject.name=${HOT_POD},reason=Pulling \
  -o jsonpath='{.items[0].firstTimestamp}')
T_PULLED=$(kubectl -n benchmark-dragonfly get events \
  --field-selector involvedObject.name=${HOT_POD},reason=Pulled \
  -o jsonpath='{.items[0].firstTimestamp}')

echo "Hot pull:"
echo "  Pulling: $T_PULLING"
echo "  Pulled:  $T_PULLED"
HOT_SECONDS=$(($(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$T_PULLED" "+%s") - $(date -j -f "%Y-%m-%dT%H:%M:%SZ" "$T_PULLING" "+%s")))
echo "  Duration: ${HOT_SECONDS}s"
```

### 4.4 Compare

```sh
echo ""
echo "=== Results ==="
echo "Cold (back-to-source): ${COLD_SECONDS}s"
echo "Hot  (P2P):            ${HOT_SECONDS}s"
echo "Improvement:           $(( (COLD_SECONDS - HOT_SECONDS) * 100 / COLD_SECONDS ))%"
```

### 4.5 Cleanup

```sh
kubectl -n benchmark-dragonfly delete job/cold-pull
kubectl -n benchmark-dragonfly delete job/hot-pull
```

Expected: hot pull is 40-70% faster than cold pull.

## Phase 5: Verify P2P Was Used

The timing alone doesn't prove P2P was used. Check the dfdaemon logs on the hot node to confirm pieces were served from P2P peers.

### 5.1 Find the dfdaemon pod on NODE_1

```sh
DF_POD=$(kubectl -n dragonfly-system get pods -l component=client \
  -o jsonpath="{.items[?(@.spec.nodeName=='${NODE_1}')].metadata.name}")
echo "dfdaemon pod on $NODE_1: $DF_POD"
```

### 5.2 Check piece sources

```sh
kubectl -n dragonfly-system logs "$DF_POD" -c client 2>&1 \
  | grep -oE "from (parent|local|back)" \
  | sort | uniq -c | sort -rn
```

Expected output:
```
    132 from parent       ← P2P pieces from other nodes
     11 from local        ← small config/manifest layers served locally
```

If you see `from back`, pieces were fetched back-to-source (P2P miss). A few `from back` is normal for the first layer; all `from back` means P2P is not working.

### 5.3 Check which peers served pieces

```sh
kubectl -n dragonfly-system logs "$DF_POD" -c client 2>&1 \
  | grep -oE 'from parent "[^"]*"' \
  | sort | uniq -c | sort -rn | head -5
```

Expected (with private IP patch):
```
  60 from parent "192.168.145.5-lke625618-..."   ← cold node via private network
   3 from parent "10.2.1.130-dragonfly-seed-client-0-..."  ← seed client
```

Expected (without private IP patch):
```
  60 from parent "172.236.22.91-lke625618-..."   ← cold node via public network
   3 from parent "10.2.1.130-dragonfly-seed-client-0-..."  ← seed client
```

### 5.4 Check for transport errors

```sh
kubectl -n dragonfly-system logs "$DF_POD" -c client 2>&1 \
  | grep -iE "transport error|failed to connect|ConnectError" \
  | head -5
```

Expected: no output (no errors). If you see `transport error`, the Cloud Firewall is blocking P2P traffic. Verify [Phase 1.6](#16-verify-cloud-firewall-allows-p2p-traffic).

### 5.5 Extract per-layer dfdaemon download time (optional)

The kubelet `Pulling`→`Pulled` timing includes containerd layer unpacking (decompression + overlayfs snapshots), which is the same for both cold and hot pulls. To see the actual P2P transfer time in isolation, check the dfdaemon `download task, cost` log lines:

```sh
# Cold node (NODE_0) — back-to-source download times
COLD_DF_POD=$(kubectl -n dragonfly-system get pods -l component=client \
  -o jsonpath="{.items[?(@.spec.nodeName=='${NODE_0}')].metadata.name}")
kubectl -n dragonfly-system logs "$COLD_DF_POD" -c client 2>&1 \
  | grep "download task, cost" \
  | sed -E 's/.*cost: ([0-9.]+)s, size: ([0-9]+).*/  \1s  \2 bytes/'

# Hot node (NODE_1) — P2P download times
kubectl -n dragonfly-system logs "$DF_POD" -c client 2>&1 \
  | grep "download task, cost" \
  | sed -E 's/.*cost: ([0-9.]+)s, size: ([0-9]+).*/  \1s  \2 bytes/'

# Also check first/last piece timestamps for P2P transfer duration
kubectl -n dragonfly-system logs "$DF_POD" -c client 2>&1 \
  | grep "finished piece" \
  | grep -oE "[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]+" \
  | head -1   # first piece
kubectl -n dragonfly-system logs "$DF_POD" -c client 2>&1 \
  | grep "finished piece" \
  | grep -oE "[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]+" \
  | tail -1   # last piece
```

The P2P transfer time (first→last piece) is typically 1-3 seconds for a ~400 MB image. The rest of the hot pull time is containerd unpacking.

## Phase 6: Cleanup

### 6.1 Delete the Jobs

```sh
kubectl -n benchmark-dragonfly delete job cold-pull hot-pull --ignore-not-found
```

### 6.2 Delete the namespace

```sh
kubectl delete namespace benchmark-dragonfly --ignore-not-found --timeout=120s
```

### 6.3 Remove the image from nodes (optional)

```sh
for NODE in "$NODE_0" "$NODE_1"; do
  cat <<PODEOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: cleanup-${NODE##*-}
  namespace: default
spec:
  restartPolicy: Never
  nodeSelector:
    kubernetes.io/hostname: ${NODE}
  tolerations:
    - operator: Exists
  hostPID: true
  containers:
    - name: c
      image: docker.io/dragonflyoss/client:v1.4.0
      securityContext:
        privileged: true
      command:
        - sh
        - -c
        - |
          nsenter --mount=/proc/1/ns/mnt -- sh -c "crictl rmi '${IMAGE}' 2>&1 | grep -v WARNING || true; echo DONE"
PODEOF
  kubectl wait pod/cleanup-${NODE##*-} --for=jsonpath='{.status.phase}'=Succeeded --timeout=120s
  kubectl logs cleanup-${NODE##*-}
  kubectl delete pod cleanup-${NODE##*-} --ignore-not-found --timeout=30s
done
done
```

### 6.4 Purge dfdaemon caches (optional)

```sh
for NODE in "$NODE_0" "$NODE_1"; do
  POD=$(kubectl -n dragonfly-system get pods -l component=client \
    -o jsonpath="{.items[?(@.spec.nodeName=='${NODE}')].metadata.name}")
  kubectl -n dragonfly-system exec "$POD" -c client -- \
    sh -c 'rm -rf /var/lib/dragonfly/content/tasks/* 2>/dev/null'
  kubectl -n dragonfly-system delete pod "$POD" --ignore-not-found --timeout=60s
done
```

## Troubleshooting

### Both pulls take ~2s (no difference)

**Cause:** containerd has the image blobs cached from a previous pull. `crictl rmi` only removes the image tag, not the underlying blob layers. containerd's garbage collector is lazy and doesn't remove orphaned blobs immediately.

**Fix:** Use a **different image** that has never been pulled on the cluster. This is the only reliable way to get a true cold pull without restarting containerd.

**Verification:** Check the dfdaemon logs on the cold node. If you see only 1 proxy request for a tiny blob (< 20 KB), the layers were served from containerd's local cache, not through Dragonfly:

```sh
kubectl -n dragonfly-system logs <cold-node-dfdaemon-pod> -c client 2>&1 \
  | grep "proxy HTTP request via dfdaemon" | wc -l
# If this is 0 or 1, containerd served from cache — benchmark is invalid
```

### Hot pull is slower than cold pull

**Cause 1:** Cloud Firewall is blocking P2P traffic between nodes.

**Check:**
```sh
kubectl -n dragonfly-system logs <hot-node-dfdaemon-pod> -c client 2>&1 \
  | grep -iE "transport error|failed to connect|ConnectError"
```

If you see `ConnectError cause: transport error`, the Cloud Firewall is dropping P2P connections. Fix:
```sh
./scripts/install-cloud-firewall.sh
```

**Cause 2:** dfdaemon is advertising its public IP, and the firewall rules only cover the private network range.

**Check:** See [Phase 1.5](#15-check-what-ip-dfdaemon-advertises-to-the-scheduler). If peers show public IPs (`172.x.x.x`) and the firewall rules only allow `192.168.128.0/17`, P2P connections will be dropped. Either apply the private IP patch or add the node public IPs to the firewall rules.

### No P2P pieces at all (all `from local` or `from back`)

**Cause:** dfdaemon is not registered with the scheduler, or the scheduler is down.

**Check:**
```sh
kubectl -n dragonfly-system get pods -l component=scheduler
kubectl -n dragonfly-system logs dragonfly-scheduler-0 --tail=20
```

### `component=client` label selector returns no pods

**Cause:** The Dragonfly chart uses short labels (`component=client`), not the standard Helm labels (`app.kubernetes.io/component=client`). This is a chart-specific behavior.

**Fix:** Always use `-l component=client`, not `-l app.kubernetes.io/component=client`.

### `kubectl run` helper pods don't show logs

**Cause:** The pod may not have finished its command before you query logs. Add a `sleep` in the command, or wait longer before querying.

**Fix:**
```sh
kubectl wait pod/<pod-name> --for=jsonpath='{.status.phase}'=Succeeded --timeout=60s
kubectl logs <pod-name>
```

## How to Read the Results

| Metric | What it measures | Expected cold | Expected hot |
|--------|-----------------|---------------|--------------|
| Kubelet Pulling→Pulled | Full pull time (download + unpack) | 13-21s (400 MB image) | 5-11s |
| dfdaemon download cost | Per-layer P2P transfer time only | 2-3s per layer (from Docker Hub) | < 1s per layer (from P2P peer) |
| P2P piece transfer (first→last piece) | Total P2P data transfer | N/A (back-to-source) | 1-3s |
| Improvement % | `(cold - hot) / cold * 100` | — | 40-70% |

### Why the hot pull is faster

The cold pull fetches every layer from Docker Hub over the public internet. The hot pull fetches layers from the cold node's NVMe cache via the intra-cluster network (private or public, depending on whether the patch is applied). The P2P transfer is faster because:

1. **No internet round-trip:** pieces are served from a node in the same datacenter, not from Docker Hub's CDN.
2. **Parallel piece fetching:** Dragonfly splits each layer into pieces and downloads them concurrently from multiple peers.
3. **NVMe read speed:** the cold node serves pieces from its local NVMe cache at ~3 GB/s, much faster than Docker Hub's per-connection bandwidth.

### Why the improvement varies

- **Image size:** larger images show more improvement (transfer time dominates over containerd unpacking).
- **Image layer count:** more layers = more parallel P2P streams.
- **Concurrent pulls:** with 3+ nodes pulling simultaneously, the P2P advantage multiplies (one cold node seeds many peers).
- **Registry speed:** if Docker Hub is rate-limiting or slow, P2P from local NVMe is dramatically faster.
- **containerd unpacking:** both cold and hot pulls spend time decompressing layers and creating overlayfs snapshots. This overhead is constant and limits the maximum improvement for small images.
