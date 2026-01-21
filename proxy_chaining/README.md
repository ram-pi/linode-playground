# Proxy Chaining with Envoy Gateway on Linode LKE

A production-ready demonstration of advanced gateway routing patterns using Envoy Gateway, Kubernetes Gateway API, and Linode cloud infrastructure. This example showcases multi-backend routing, automated DNS management, TLS certificate provisioning, and static site hosting via Object Storage.

## Overview

This example provisions a complete cloud-native infrastructure demonstrating:

- **Kubernetes Gateway API** implementation with Envoy Gateway
- **Multi-backend routing** (in-cluster services + external S3-compatible storage)
- **Automated DNS management** via ExternalDNS and Linode DNS
- **Automatic TLS certificates** using cert-manager and Let's Encrypt
- **High-availability LKE cluster** with control plane ACLs
- **Static website hosting** on Linode Object Storage with Gateway proxy

## Architecture

![Architecture Diagram](drawio.svg)

### Components

- **LKE Cluster**: High-availability Kubernetes cluster with control plane ACLs
- **Envoy Gateway**: Modern Gateway API implementation for traffic routing (exposed via Kubernetes LoadBalancer service)
- **Linode NodeBalancer**: Automatically provisioned by LKE when Envoy Gateway creates its LoadBalancer service, provides the public IP for ingress traffic
- **cert-manager**: Automated TLS certificate management (Let's Encrypt)
- **ExternalDNS**: Automatic DNS record creation in Linode DNS
- **Linode Object Storage**: S3-compatible static site hosting
- **Bastion Host**: Jump server for secure cluster access

## Technology Stack

### Infrastructure
- **Linode Cloud Platform** - Cloud infrastructure provider
- **OpenTofu/Terraform** - Infrastructure as Code
- **Linode LKE (Kubernetes)** v1.34 - Managed Kubernetes service

### Kubernetes Components
- **Envoy Gateway** - Gateway API controller
- **cert-manager** v1.x - Certificate management
- **ExternalDNS** - DNS automation
- **[cert-manager-webhook-linode](https://github.com/linode/cert-manager-webhook-linode)** - DNS-01 challenge integration for Linode DNS

### Gateway & Routing
- **Kubernetes Gateway API** v1 - Modern ingress specification
- **HTTPRoute** - HTTP traffic routing
- **Backend CRD** - External backend integration (Envoy Gateway extension)

### Storage & Services
- **Linode Object Storage** - S3-compatible object storage
- **Nginx** - Example backend service

## Prerequisites

- **Linode Account** with API token
- **Domain name** from a registrar (e.g., Namecheap, GoDaddy) with nameservers pointed to Linode's DNS servers
- **OpenTofu/Terraform** >= 1.6
- **kubectl** >= 1.27
- **Helm** >= 3.12
- **bash** shell

### Domain Setup

Linode does not sell domains. Purchase a domain from a registrar like Namecheap, then:

1. Log in to your domain registrar
2. Update nameservers to Linode's:
   - `ns1.linode.com`
   - `ns2.linode.com`
   - `ns3.linode.com`
   - `ns4.linode.com`
   - `ns5.linode.com`
3. Wait for DNS propagation (up to 24-48 hours)

Once configured, Terraform will manage DNS records via Linode's API.

## Getting Started

### 1. Clone and Configure

```bash
cd proxy_chaining
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:

```hcl
domain = "yourdomain.com"
email  = "admin@yourdomain.com"
ipv4_whitelist_cidrs = ["YOUR_IP/32"]  # For LKE control plane ACL
```

### 2. Provision Infrastructure

```bash
# Initialize Terraform
tofu init

# Review planned changes
tofu plan

# Apply infrastructure
tofu apply
```

This creates:
- LKE cluster (HA control plane, 3-6 worker nodes)
- Linode DNS domain and records
- Object Storage bucket for static website
- Bastion host with SSH access
- Firewall rules

### 3. Configure Kubernetes

```bash
# Export kubeconfig
tofu output -raw lke_kubeconfig > kubeconfig
export KUBECONFIG=$(pwd)/kubeconfig

# Verify cluster access
kubectl get nodes
```

### 4. Deploy Gateway Stack

```bash
# Run post-installation script
./scripts/post-installation.sh <LINODE_API_TOKEN> yourdomain.com
```

This installs:
- Envoy Gateway with Backend CRD enabled (creates a Kubernetes LoadBalancer service)
- Linode NodeBalancer (automatically provisioned by LKE for the LoadBalancer service)
- ExternalDNS configured for Linode
- cert-manager with Let's Encrypt ClusterIssuer
- Gateway and HTTPRoute resources
- Example Nginx backend

### 5. Verify Deployment

```bash
# Check Gateway status
kubectl get gateway -n web-demo

# Check HTTPRoutes
kubectl get httproute -n web-demo

# Check certificates
kubectl get certificate -n web-demo

# Check DNS records (wait 2-5 minutes)
dig api.yourdomain.com
dig static.yourdomain.com

# Test endpoints (wait for certificate issuance)
curl https://api.yourdomain.com
curl https://static.yourdomain.com
```

## Project Structure

```
proxy_chaining/
├── main.tf              # Local variables and core configuration
├── providers.tf         # Provider configuration (Linode, TLS, etc.)
├── variables.tf         # Input variables
├── lke.tf              # LKE cluster definition
├── compute.tf          # Bastion host configuration
├── network.tf          # Firewall rules
├── dns.tf              # Linode DNS domain
├── storage.tf          # Object Storage bucket and objects
├── outputs.tf          # Output values (kubeconfig, URLs, SSH)
├── configs/
│   ├── gateway.yaml              # Gateway and GatewayClass
│   ├── httproute.api.yaml        # HTTPRoute for in-cluster service
│   ├── httproute.static.yaml     # HTTPRoute + Backend for S3
│   ├── cluster-issuer.yaml       # cert-manager ClusterIssuer
│   ├── web-server.yaml           # Example Nginx deployment
│   └── envoy-gateway.values.yaml # Envoy Gateway Helm values
├── scripts/
│   ├── post-installation.sh      # Automated K8s setup
│   ├── uninstall.sh             # Cleanup script
│   └── cloud-init.yaml.tpl      # Bastion host initialization
├── modules/
│   └── helm-releases/           # Helm chart deployments (if any)
└── website/
    ├── index.html               # Static site content
    └── 404.html                 # Error page
```

## Key Features

### Multi-Subdomain Routing

The Gateway supports multiple subdomains with distinct backends:

- **api.yourdomain.com** → Nginx service (in-cluster)
- **static.yourdomain.com** → Linode Object Storage (external)

Each subdomain gets:
- Dedicated HTTPS listener on the Gateway
- Automatic DNS A record via ExternalDNS
- Automatic TLS certificate via cert-manager
- Custom routing rules via HTTPRoute

### External Backend Integration

The `static.yourdomain.com` route demonstrates advanced features:

- **Backend CRD**: Envoy Gateway extension for external endpoints
- **TLS to backend**: HTTPS connection to S3 with SNI
- **Host header rewrite**: Changes `Host` from `static.yourdomain.com` to S3 bucket hostname
- **System CA trust**: Validates S3 TLS certificate

### Automated Certificate Management

cert-manager handles TLS certificates automatically:

1. **Gateway annotation** triggers certificate issuance
2. **HTTP-01 challenge** via Gateway's HTTP listener
3. **Let's Encrypt** provides production certificates
4. **Auto-renewal** before expiration

### DNS Automation

ExternalDNS synchronizes Kubernetes resources to Linode DNS:

- Watches `HTTPRoute` resources
- Creates/updates A records pointing to Gateway LoadBalancer
- Configurable TTL (default: 300s)
- Automatic cleanup on resource deletion

## Configuration Details

### Enabling Backend CRD

The `Backend` resource requires explicit enablement in Envoy Gateway. This is configured in [configs/envoy-gateway.values.yaml](configs/envoy-gateway.values.yaml):

```yaml
# configs/envoy-gateway.values.yaml
config:
  envoyGateway:
    extensionAPIs:
      enableBackend: true
```

Without this, routes referencing `Backend` will return 500 errors.

### TLS Backend Configuration

When routing to external HTTPS endpoints (see [configs/httproute.static.yaml](configs/httproute.static.yaml)):

```yaml
spec:
  tls:
    sni: backend.hostname.com
    wellKnownCACertificates: System  # Use system CA bundle
```

The `sni` field sets the SNI hostname for the upstream TLS handshake.

### Host Header Rewriting

For S3/object storage backends that route by `Host` header (configured in [configs/httproute.static.yaml](configs/httproute.static.yaml)):

```yaml
filters:
  - type: URLRewrite
    urlRewrite:
      hostname: bucket-name.s3.endpoint.com
```

This ensures the backend receives the bucket hostname, not the client's `Host`.

## Development Workflow

### Adding a New Subdomain

1. **Add listener** to [configs/gateway.yaml](configs/gateway.yaml):
   ```yaml
   - name: mysubdomain
     port: 443
     protocol: HTTPS
     hostname: "mysubdomain.${DOMAIN}"
     tls:
       mode: Terminate
       certificateRefs:
         - name: ${DOMAIN_CERT_NAME}-tls
   ```

2. **Create HTTPRoute** (e.g., `configs/httproute.mysubdomain.yaml`):
   ```yaml
   apiVersion: gateway.networking.k8s.io/v1
   kind: HTTPRoute
   metadata:
     name: mysubdomain-route
     annotations:
       external-dns.alpha.kubernetes.io/hostname: mysubdomain.${DOMAIN}.
   spec:
     parentRefs:
       - name: main-gateway
     hostnames:
       - mysubdomain.${DOMAIN}
     rules:
       - backendRefs:
           - name: my-service
             port: 80
   ```

3. **Apply configuration**:
   ```bash
   kubectl apply -f configs/httproute.mysubdomain.yaml
   ```

cert-manager and ExternalDNS handle the rest automatically.

### Debugging

#### Check Gateway Status
```bash
kubectl describe gateway main-gateway -n web-demo
```

#### View Envoy Gateway Logs
```bash
kubectl logs -n envoy-gateway-system deployment/envoy-gateway -f
```

#### Check Certificate Issuance
```bash
kubectl describe certificate -n web-demo
kubectl logs -n cert-manager deployment/cert-manager -f
```

#### Verify DNS Records
```bash
kubectl logs -n external-dns deployment/external-dns -f
dig @8.8.8.8 api.yourdomain.com
```

#### Test Backend Connectivity
```bash
# From within cluster
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -v https://static-site-xxx.website-it-mil-1.linodeobjects.com/
```

## Common Issues

### 500 Error: "Backend is disabled"

**Cause**: Backend CRD feature not enabled in Envoy Gateway.

**Solution**: Ensure `enableBackend: true` in Helm values:
```bash
helm upgrade envoy-gateway oci://docker.io/envoyproxy/gateway-helm \
  --namespace envoy-gateway-system \
  --set config.envoyGateway.extensionAPIs.enableBackend=true
```

### 500 Error: "must specify either CACertificateRefs or WellKnownCACertificates"

**Cause**: TLS enabled on Backend without CA configuration.

**Solution**: Add `wellKnownCACertificates: System` to Backend spec.

### Certificate Not Issuing

**Cause**: HTTP-01 challenge failing or domain not resolving.

**Solution**:
1. Verify DNS record points to Gateway LoadBalancer IP
2. Check HTTP listener is configured on port 80
3. Review cert-manager logs for challenge status

### DNS Records Not Created

**Cause**: ExternalDNS not watching HTTPRoute or missing annotations.

**Solution**:
1. Verify ExternalDNS source includes `gateway-httproute`
2. Add annotation: `external-dns.alpha.kubernetes.io/hostname: subdomain.domain.com.`
3. Check ExternalDNS logs for errors

## Cleanup

```bash
# Run uninstall script
./scripts/uninstall.sh

# Destroy infrastructure
tofu destroy

# Remove kubeconfig
rm -f kubeconfig
```

## Security Considerations

- **Control Plane ACL**: Restricts LKE API access to whitelisted IPs (configured in [lke.tf](lke.tf))
- **TLS Everywhere**: HTTPS for client connections, optional TLS to backends
- **Secret Management**: Linode API token stored as Kubernetes Secret
- **Least Privilege**: Service accounts with minimal RBAC permissions

## Cost Optimization

- **Autoscaling**: LKE node pool scales 3-6 nodes based on load
- **Shared Gateway**: Single LoadBalancer serves multiple domains
- **Object Storage**: Pay-per-use pricing for static assets
- **Resource Requests**: Pods sized appropriately to maximize density

## Further Reading

- [Kubernetes Gateway API](https://gateway-api.sigs.k8s.io/)
- [Envoy Gateway Documentation](https://gateway.envoyproxy.io/)
- [cert-manager Documentation](https://cert-manager.io/docs/)
- [ExternalDNS Documentation](https://kubernetes-sigs.github.io/external-dns/)
- [Akamai Cloud Computing - Object Storage](https://techdocs.akamai.com/cloud-computing/docs/object-storage)
- [Akamai Cloud Computing - Kubernetes (LKE)](https://techdocs.akamai.com/cloud-computing/docs/getting-started-with-lke)
