# Secret Management on LKE with OpenBao

Comprehensive secrets management solution for Kubernetes using OpenBao (open-source Vault alternative). This setup demonstrates HA cluster deployment with auto-unsealing, multiple secret injection methods, and integration with External Secrets Operator.

## Architecture

![diagram](drawio.svg)

## Features

- **High Availability**: 3-node OpenBao cluster with Raft storage backend
- **Auto-unsealing**: Static key-based automatic unsealing on pod restart
- **Multiple Secret Injection Methods**: CSI Driver, Injector sidecar, and External Secrets Operator
- **Prometheus Metrics**: Built-in metrics exposure for monitoring
- **Kubernetes Native**: ServiceAccount-based authentication for applications

## Quick Start

### 1. Deploy OpenBao Cluster

First, set your Linode API token and deploy the cluster:

```bash
export LINODE_TOKEN='your-token-here'
./start.sh
```

### 2. Initialize OpenBao

Generate unsealing key and initialize the cluster:

```
# Generate a random 32-byte key
openssl rand -out master.key 32

# Generate a UUID for the key ID (required for static seal)
uuidgen > master.key.id

# Save the key in a kubernetes secret
kubectl create namespace openbao
kubectl create secret generic openbao-unseal-key \
  --namespace openbao \
  --from-file=current_key=master.key \
  --from-file=current_key_id=master.key.id

helm repo add openbao https://openbao.github.io/openbao-helm
helm repo update
helm upgrade --install openbao openbao/openbao \
  --namespace openbao \
  --values configs/openbao.values.yaml

# Remember to save the output
# You will need the token to login
kubectl exec -ti openbao-0 -n openbao -- bao operator init
exit
```

### Troubleshooting

#### Join other nodes (Raft)

It should be done automatically, if not you can run the following commands:

```
kubectl exec -ti openbao-1 -n openbao -- bao operator raft join http://openbao-0.openbao-internal:8200
kubectl exec -ti openbao-2 -n openbao -- bao operator raft join http://openbao-0.openbao-internal:8200
```

#### Check Cluster Status

Verify that all nodes are properly unsealed:

```
kubectl exec -ti openbao-0 -n openbao -- bao status
kubectl exec -ti openbao-1 -n openbao -- bao status
kubectl exec -ti openbao-2 -n openbao -- bao status
```

#### Test Auto-unseal

Verify that pods automatically unseal after a crash:

```
kubectl delete pod openbao-2 -n openbao

# Check if sealed or not - we expect Sealed: false
kubectl exec -ti openbao-2 -n openbao -- bao status
```

### Verify metrics are exposed

```
# Port-forward to the active node
kubectl port-forward openbao-0 -n openbao 8200:8200

# Check metrics locally on your machine
curl http://localhost:8200/v1/sys/metrics?format=prometheus
```

#### PodMonitor

```
apiVersion: monitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: openbao-monitor
  namespace: openbao
  labels:
    release: prometheus # Change this to match your Prometheus serviceMonitorSelector
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: openbao
      app.kubernetes.io/instance: openbao
  podMetricsEndpoints:
  - port: http
    path: /v1/sys/metrics
    params:
      format: ["prometheus"]
    interval: 30s
  namespaceSelector:
    matchNames:
    - openbao
```

## Secrets Store CSI Driver Setup

```
helm repo add secrets-store-csi-driver https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts
helm install csi-secrets-store secrets-store-csi-driver/secrets-store-csi-driver --namespace kube-system
```

### Usage

#### OpenBao Configuration

```
kubectl exec -ti openbao-0 -n openbao -- sh

bao login <YOUR_ROOT_TOKEN>

# Enable KV-v2 secrets engine (if not already enabled)
bao secrets enable -version=2 -path=secret kv

# Write a dummy secret
bao kv put secret/my-csi-app username=admin password=s3cr3t

# Enable Kubernetes Auth
bao auth enable kubernetes

# Configure the auth method
# Since we are running inside the cluster, use the internal environment variables
bao write auth/kubernetes/config \
    kubernetes_host="https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_SERVICE_PORT"

bao policy write my-csi-policy - <<EOF
path "secret/data/my-csi-app" {
  capabilities = ["read"]
}
EOF

bao write auth/kubernetes/role/csi-role \
    bound_service_account_names=csi-sa \
    bound_service_account_namespaces=default \
    policies=my-csi-policy \
    ttl=1h

exit
```

#### Kubernetes Integration

```
kubectl apply -f configs/csi-demo.yaml
```

Check if the secret exists at the path **/mnt/secrets/**.

## Injector Setup

### Usage

#### OpenBao Configuration

```
kubectl exec -ti openbao-0 -n openbao -- sh

bao login <YOUR_ROOT_TOKEN>

# Enable KV-v2 secrets engine (if not already enabled)
bao secrets enable -version=2 -path=secret kv

# Write a dummy secret
bao kv put secret/my-app-config content=-<<EOF
server.port=8080
logging.level=DEBUG
database.url=jdbc:postgresql://db:5432/myapp
EOF

# Enable Kubernetes Auth
bao auth enable kubernetes

# Configure the auth method
# Since we are running inside the cluster, use the internal environment variables
bao write auth/kubernetes/config \
    kubernetes_host="https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_SERVICE_PORT"

bao policy write my-injector-policy - <<EOF
path "secret/data/my-app-config" {
  capabilities = ["read"]
}
EOF

bao write auth/kubernetes/role/injector-role \
    bound_service_account_names=injector-sa \
    bound_service_account_namespaces=default \
    policies=my-injector-policy \
    ttl=1h

exit
```

#### Kubernetes Integration

```
kubectl apply -f configs/injector-demo.yaml
```

Verify the secret is injected in the container at the path **/vault/secrets/**.


## ESO + OpenBao

### ESO Setup

```
helm repo add external-secrets https://charts.external-secrets.io
helm repo update

helm install external-secrets external-secrets/external-secrets \
    -n external-secrets \
    --create-namespace \
    --set installCRDs=true
```

### Configure OpenBao

```
kubectl exec -ti openbao-0 -n openbao -- sh

bao login <YOUR_ROOT_TOKEN>

bao kv put secret/eso-demo api-key="12345-ABCDE-ESO" environment="production"

bao policy write eso-policy - <<EOF
# Allow reading the secret data
path "secret/data/eso-demo" {
  capabilities = ["read"]
}
# (Optional but recommended) Allow checking if the secret exists
path "secret/metadata/eso-demo" {
  capabilities = ["list", "read"]
}
EOF

bao write auth/kubernetes/role/eso-role \
    bound_service_account_names=eso-sa \
    bound_service_account_namespaces=default \
    policies=eso-policy \
    ttl=1h

exit
```

### Connect ESO to OpenBao

```
kubectl apply -f configs/eso-setup.yaml
kubectl apply -f configs/eso-sync.yaml
```

Check if the secret exists: `kubectl describe secrets -n default my-native-secret`.
