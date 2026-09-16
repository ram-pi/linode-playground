# Manual Deployment

Use this if you want to run the phases separately instead of relying on `start.sh`.

## 1. Provision Infrastructure

```bash
export LINODE_TOKEN="..."
tofu init
tofu apply
export KUBECONFIG="$PWD/kubeconfig"
```

This creates the LKE Enterprise cluster and writes the kubeconfig.

## 2. Install cert-manager and the CSI Driver

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo update jetstack

helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --version v1.21.1 --set installCRDs=true

helm upgrade --install cert-manager-csi-driver jetstack/cert-manager-csi-driver \
  --namespace cert-manager --create-namespace \
  --version v0.16.0

kubectl -n cert-manager rollout status deployment/cert-manager --timeout=5m
kubectl -n cert-manager rollout status deployment/cert-manager-webhook --timeout=5m
kubectl -n cert-manager rollout status daemonset/cert-manager-csi-driver --timeout=5m
```

The CSI driver DaemonSet must be Ready before applying any workload that mounts a `csi.cert-manager.io` volume; otherwise pods hang in `ContainerCreating` waiting for the CSI socket to be registered on the node.

## 3. Create the Root CA and Namespace

```bash
kubectl apply -f configs/00-namespace.yaml
kubectl apply -f configs/10-root-ca.yaml
kubectl -n cert-manager wait --for=condition=Ready certificate/root-ca --timeout=5m
```

This creates the SelfSigned issuer, the root CA `Certificate` (stored in the `root-ca` Secret), and the `root-ca-issuer` CA `ClusterIssuer`.

## 4. Render and Apply the Workloads

The DaemonSet and reader pod templates use `${CERT_DURATION}`. Render them with your chosen TTL (default `30m`):

```bash
export CERT_DURATION="30m"
sed "s/\${CERT_DURATION}/$CERT_DURATION/g" configs/20-node-cert-daemonset.yaml.tpl > configs/20-node-cert-daemonset.yaml
sed "s/\${CERT_DURATION}/$CERT_DURATION/g" configs/30-reader-pod.yaml.tpl > configs/30-reader-pod.yaml

kubectl apply -f configs/20-node-cert-daemonset.yaml
kubectl apply -f configs/30-reader-pod.yaml
```

## 4. Verify

```bash
kubectl -n cert-manager-csi-demo rollout status daemonset/node-cert-reader --timeout=5m
kubectl -n cert-manager-csi-demo wait --for=condition=Ready pod/cert-reader-pod --timeout=5m

# Per-node certificates
kubectl -n cert-manager-csi-demo logs -l app=node-cert-reader --all-containers=true --prefix=true

# Reader pod certificate
kubectl -n cert-manager-csi-demo logs pod/cert-reader-pod
```

Each log shows the certificate subject, issuer, validity dates, SANs, and an `openssl verify` result against the root CA.

## 5. Cleanup

```bash
kubectl delete namespace cert-manager-csi-demo --ignore-not-found=true
tofu destroy
```
