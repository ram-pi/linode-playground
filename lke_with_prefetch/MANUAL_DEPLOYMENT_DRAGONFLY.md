# Manual Deployment: Dragonfly P2P Image Cache with kube-fledged

## How It Works

```text
ImageCache
  -> kube-fledged controller
  -> one pull Job per node
  -> node-local containerd
  -> Dragonfly dfdaemon on 127.0.0.1:4001
  -> Dragonfly scheduler coordinates P2P layer downloads
  -> upstream registry is used only for back-to-source misses
```

kube-fledged still creates concurrent pull Jobs. Dragonfly is the component that avoids every node independently downloading every layer from the upstream registry.

## Prerequisites

- LKE cluster provisioned by this demo.
- `kubectl`, `helm`, and `jq` installed locally.
- Local kubeconfig available at `./kubeconfig.yaml`.

Set the kubeconfig path once:

```sh
export KUBECONFIG="./kubeconfig.yaml"
```

## Phase 1: Install Dragonfly

Add the Helm repository:

```sh
helm repo add dragonfly https://dragonflyoss.github.io/helm-charts/
helm repo update dragonfly
```

Install Dragonfly:

```sh
helm upgrade --install dragonfly dragonfly/dragonfly \
  --namespace dragonfly-system \
  --create-namespace \
  -f configs/dragonfly/values.yaml \
  --wait --timeout 10m
```

Verify Dragonfly components:

```sh
kubectl -n dragonfly-system get pods -o wide
kubectl -n dragonfly-system get svc
```

Confirm the dfdaemon proxy port from the installed config:

```sh
kubectl -n dragonfly-system get cm dragonfly-client -o jsonpath='{.data.dfdaemon\.yaml}'
```

This demo expects the proxy server port to be `4001`.

## Phase 2: Verify containerd Mirror Configuration

This demo uses the Dragonfly chart values in `configs/dragonfly/values.yaml`, which enable `client.dfinit` to write the containerd mirror configuration on each node during install.

The resulting mirror configuration should look like this:

```toml
[host."http://127.0.0.1:4001"]
  capabilities = ["pull", "resolve"]
  [host."http://127.0.0.1:4001".header]
    X-Dragonfly-Registry = ["https://registry-1.docker.io"]
```

On the first install, `client.dfinit.restartContainerRuntime=true` may restart containerd on each node so the mirror configuration is loaded. That can briefly disrupt running pods. For routine upgrades after the first successful install, set `client.dfinit.restartContainerRuntime=false` in `configs/dragonfly/values.yaml`.

To inspect the rendered dfinit configuration:

```sh
kubectl -n dragonfly-system get cm dragonfly-dfinit -o json \
  | jq -r '.data["dfinit.yaml"] // .data["dfinit.yml"] // "dfinit config key not found in ConfigMap data"'
```

If the key is not present, verify the node-level mirror config directly:

```sh
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
kubectl debug node/$NODE -it --image=alpine:3.22 -- chroot /host \
  sh -lc 'cat /etc/containerd/certs.d/_default/hosts.toml 2>/dev/null || true; echo; cat /etc/containerd/certs.d/docker.io/hosts.toml 2>/dev/null || true'
```

With `proxyAllRegistries: true`, `_default/hosts.toml` is the primary catch-all mirror configuration. Per-registry files such as `docker.io/hosts.toml` can still exist when explicit registry entries are configured.

## Phase 3: Install kube-fledged

Add the Helm repository:

```sh
helm repo add kubefledged-charts https://senthilrch.github.io/kubefledged-charts/
helm repo update kubefledged-charts
```

Install kube-fledged:

```sh
helm upgrade --install kube-fledged kubefledged-charts/kube-fledged \
  --namespace kube-fledged \
  --create-namespace \
  -f configs/kube-fledged/values.yaml \
  --wait --timeout 5m
```

The default demo values in `configs/kube-fledged/values.yaml` keep kube-fledged internal-only, extend the pull deadline to `60m`, and set `controllerImageCacheRefreshFrequency=6h` to repair node cache drift without excessive refresh traffic.

If you want deterministic tests with no automatic refresh, temporarily set `controllerImageCacheRefreshFrequency: 0s` in `configs/kube-fledged/values.yaml` before installing or upgrading.

Verify the rendered controller args:

```sh
kubectl -n kube-fledged get deploy kube-fledged-controller -o jsonpath='{.spec.template.spec.containers[0].args}'
```

Expected flags include:

```text
--image-cache-refresh-frequency=6h
--image-pull-deadline-duration=60m
```

## Phase 4: Create the ImageCache

Review the image list:

```sh
kubectl apply --dry-run=server -f configs/imagecache.yaml
```

Apply it:

```sh
kubectl apply -f configs/imagecache.yaml
```

Monitor kube-fledged:

```sh
kubectl -n kube-fledged get imagecaches -w
```

In another terminal, watch the pull jobs:

```sh
kubectl -n kube-fledged get jobs -w
```

Check controller logs:

```sh
kubectl -n kube-fledged logs deploy/kube-fledged-controller -f
```

kube-fledged creates one pull Job per image per target node. With Dragonfly configured as the containerd registry mirror, those concurrent pulls should be routed through the local dfdaemon on each node.

## Refreshing Cached Images

Disabling periodic refresh does not immediately delete images. It only stops kube-fledged from periodically re-pulling and revalidating the ImageCache.

Images can still disappear later if:

- A node is replaced.
- containerd garbage collection removes unused content under disk pressure.
- An operator manually prunes images.
- The node is rebuilt or upgraded.

Run an on-demand refresh after node replacement, after suspected garbage collection, or before a benchmark:

```sh
kubectl annotate imagecache node-image-cache \
  -n kube-fledged kubefledged.io/refresh-imagecache="$(date +%s)" --overwrite
```

Watch it complete:

```sh
kubectl -n kube-fledged get imagecache node-image-cache -w
```

If you want to change the automatic repair cadence, update `controllerImageCacheRefreshFrequency` in `configs/kube-fledged/values.yaml` and re-run Helm. For example, to refresh more aggressively every 24 hours:

```sh
helm upgrade --install kube-fledged kubefledged-charts/kube-fledged \
  --namespace kube-fledged \
  --create-namespace \
  -f configs/kube-fledged/values.yaml \
  --set args.controllerImageCacheRefreshFrequency=24h \
  --wait --timeout 5m
```

Trade-off: automatic refresh improves cache repair after drift, but it can also generate recurring registry and Dragonfly traffic.

## Verify Images Exist on Nodes

Pick a node:

```sh
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}')
```

Inspect the node's containerd image store:

```sh
kubectl debug node/$NODE -it --image=alpine:3.22 -- chroot /host \
  crictl --runtime-endpoint unix:///run/containerd/containerd.sock images
```

This proves the image exists in containerd on that node. It does not prove how the layers were downloaded.

## Verify Dragonfly Is Being Used

Use a fresh image tag for validation. If the image is already cached in containerd or Dragonfly, there may be no upstream traffic to observe.

Start with the kube-fledged logs:

```sh
kubectl -n kube-fledged logs deploy/kube-fledged-controller -f
```

You should see one pull Job created per node.

Watch Dragonfly client logs during a fresh pull:

```sh
kubectl -n dragonfly-system logs ds/dragonfly-client -f
```

For metrics, port-forward one Dragonfly client pod at a time:

```sh
CLIENT_POD=$(kubectl -n dragonfly-system get pod \
  -l app=dragonfly,component=client -o jsonpath='{.items[0].metadata.name}')

kubectl -n dragonfly-system port-forward pod/$CLIENT_POD 4002:4002
```

In another terminal, inspect available download metrics:

```sh
curl -s http://127.0.0.1:4002/metrics | grep -E 'dragonfly_client_.*(download|task|peer|source|back)'
```

Also inspect scheduler metrics:

```sh
SCHEDULER_POD=$(kubectl -n dragonfly-system get pod \
  -l app=dragonfly,component=scheduler -o jsonpath='{.items[0].metadata.name}')

kubectl -n dragonfly-system port-forward pod/$SCHEDULER_POD 8000:8000
```

Then query:

```sh
curl -s http://127.0.0.1:8000/metrics | grep -E 'dragonfly_scheduler_.*(peer|task|source|download)'
```

The expected signal is:

- Multiple peers register for the same task or layer.
- Only a small number of peers go back-to-source for a given blob.
- Other peers download pieces from Dragonfly peers or seed peers.

Do not expect Kubernetes events to show this. Kubernetes only reports that the image was pulled by containerd. Dragonfly logs, metrics, and UI are the places to verify P2P behavior.

Also note that Dragonfly does not guarantee exactly one node goes back-to-source for every layer in every timing scenario. Concurrency, layer size, existing cache state, retry behavior, and scheduler decisions can result in more than one upstream fetch. The practical goal is much lower upstream traffic than `node_count * image_size`, not a strict single-origin invariant.

## Access the Dragonfly UI

Port-forward the manager service:

```sh
kubectl -n dragonfly-system port-forward svc/dragonfly-manager 8080:8080
```

Open:

```text
http://127.0.0.1:8080
```

The UI is useful for Dragonfly cluster, scheduler, peer, task, and preheat visibility.

Do not treat the UI as a Harbor-style image catalog. Dragonfly primarily caches download tasks, blobs, and pieces. A cached Docker image may appear as layer/blob tasks rather than as a clean `repository:tag` inventory. For node-local image inventory, use containerd via `crictl images`.

## Troubleshooting

### kube-fledged Still Refreshes Every 15 Minutes

Check the controller args:

```sh
kubectl -n kube-fledged get deploy kube-fledged-controller -o yaml \
  | grep image-cache-refresh-frequency
```

If it shows `15m`, reinstall with the chart's nested value:

```sh
helm upgrade --install kube-fledged kubefledged-charts/kube-fledged \
  --namespace kube-fledged \
  --create-namespace \
  -f configs/kube-fledged/values.yaml \
  --set args.controllerImageCacheRefreshFrequency=0s \
  --wait --timeout 5m
```

### Pulls Do Not Appear in Dragonfly

Check the containerd mirror files on the node:

```sh
kubectl debug node/$NODE -it --image=alpine:3.22 -- chroot /host \
  sh -lc 'cat /etc/containerd/certs.d/_default/hosts.toml 2>/dev/null || true; echo; cat /etc/containerd/certs.d/docker.io/hosts.toml 2>/dev/null || true'
```

Expected mirror endpoint in at least one rendered hosts.toml:

```text
http://127.0.0.1:4001
```

Check that the Dragonfly client DaemonSet is running with host networking:

```sh
kubectl -n dragonfly-system get ds dragonfly-client -o yaml \
  | grep -E 'hostNetwork|hostPID|hostIPC'
```

### Large Image Pulls Time Out

Increase the kube-fledged pull deadline:

```sh
helm upgrade --install kube-fledged kubefledged-charts/kube-fledged \
  --namespace kube-fledged \
  --create-namespace \
  -f configs/kube-fledged/values.yaml \
  --set args.controllerImagePullDeadlineDuration=90m \
  --wait --timeout 5m
```

### Docker Hub Rate Limits

Create a Docker Hub pull secret in the kube-fledged namespace and reference it from `configs/imagecache.yaml`:

```sh
kubectl create secret docker-registry dockerhub-credentials \
  --docker-server=https://index.docker.io/v1/ \
  --docker-username="$DOCKERHUB_USERNAME" \
  --docker-password="$DOCKERHUB_TOKEN" \
  --docker-email="$DOCKERHUB_EMAIL" \
  -n kube-fledged
```

Then uncomment:

```yaml
imagePullSecrets:
  - name: dockerhub-credentials
```

## Cleanup

Delete the ImageCache:

```sh
kubectl delete -f configs/imagecache.yaml
```

Uninstall kube-fledged:

```sh
helm uninstall kube-fledged -n kube-fledged
```

Uninstall Dragonfly:

```sh
helm uninstall dragonfly -n dragonfly-system
```
