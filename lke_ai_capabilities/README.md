# LKE AI Capabilities Demo

This demo deploys an LKE Enterprise cluster with the App Platform for Linode (APL) and AI capabilities using KServe and Knative.

## Architecture

![Architecture Diagram](drawio.svg)

## Features

- **App Platform for Linode (APL)**: Full-featured application platform with integrated tooling
- **Magic DNS (nip.io)**: Automatic DNS resolution without manual DNS configuration
- **Object Storage**: Linode Object Storage integration for:
  - CNPG (PostgreSQL backups)
  - Gitea (Git repository storage)
  - Harbor (Container registry storage)
  - Loki (Log aggregation storage)
- **AI/ML Capabilities**:
  - **KServe**: Model serving and inference
  - **Knative**: Serverless workload management
- **Security**: Cloud Firewall Controller for network security policies

## Prerequisites

- [OpenTofu](https://opentofu.org/) installed
- [kubectl](https://kubernetes.io/docs/tasks/tools/) installed
- [Helm](https://helm.sh/docs/intro/install/) installed
- [Linode CLI](https://www.linode.com/docs/products/tools/cli/get-started/) installed and configured
- Linode API token set as environment variable:
  ```bash
  export LINODE_TOKEN='your-token-here'
  ```

## Quick Start

### 1. Deploy the Cluster

Run the start script to provision the LKE cluster and install APL:

```bash
./start.sh
```

This script will:
1. Train NLP models (required for KServe demo)
2. Initialize and apply OpenTofu configuration
3. Wait for the LKE cluster to be ready
4. Run the post-installation script with interactive prompts

### 2. Post-Installation Steps

The post-installation script ([scripts/post_installation.sh](scripts/post_installation.sh)) will guide you through:

1. **Cloud Firewall Controller** - Install network security policies (It can be skipped in case of LKE-E clusters)
2. **NodeBalancer Setup** - Create and retrieve NodeBalancer information
3. **APL Configuration** - Build values.yaml with:
   - Magic DNS using NodeBalancer IP (e.g., `172.x.x.x.nip.io`)
   - NodeBalancer ID annotation
   - Object Storage credentials
4. **APL Installation** - Deploy APL Helm chart
5. **Verification** - Wait for APL jobs to complete and display access information

### 3. Access APL

After installation, the script will display:
- APL Console URL: `https://console.<IP>.nip.io`
- API URL: `https://api.<IP>.nip.io`
- Admin credentials

## Configuration

### APL Values

The APL configuration is based on [apl/no_domain.values.yaml](apl/no_domain.values.yaml) and includes:

- **Cluster Provider**: Custom (Linode)
- **Domain Suffix**: Auto-configured using NodeBalancer IP + nip.io
- **KServe & Knative**: Enabled for AI/ML workloads
- **Object Storage**: Linode Object Storage for all APL components
- **OAuth2 Proxy**: Includes Keycloak health check init container

### Object Storage

Object storage buckets are automatically created and configured for:
- `apl-cnpg-*`: CloudNativePG backups
- `apl-gitea-*`: Gitea repository storage
- `apl-harbor-*`: Harbor container registry
- `apl-loki-*`: Loki log aggregation

## Cleanup

To destroy all resources:

```bash
./shutdown.sh
```

This will:
1. Uninstall Helm releases (APL, Cloud Firewall Controller)
2. Wait for resource deletion
3. Run `tofu destroy`
4. Clean up generated files

## Project Structure

```
lke_ai_capabilities/
├── start.sh                      # Main deployment script
├── shutdown.sh                   # Cleanup script
├── scripts/
│   ├── post_installation.sh      # Post-install orchestration
│   ├── get_nodebalancer_info.sh  # Retrieve NodeBalancer details
│   └── get_apl_info.sh          # Display APL access info
├── apl/
│   ├── no_domain.values.yaml     # APL values template
│   ├── values.yaml              # Generated APL values (created by script)
│   └── nodebalancer_info.env    # Generated NB info (created by script)
├── resources/
│   └── dummy.svc.yaml           # Temporary service for NB creation
├── training/                     # NLP model training scripts
├── *.tf                         # OpenTofu configuration files
└── drawio.svg                   # Architecture diagram
```

## Notes

- **Magic DNS**: Uses nip.io for automatic DNS resolution (e.g., `keycloak.172.236.197.79.nip.io`)
- **Interactive Installation**: Post-installation requires confirmation at each step
- **Keycloak Health Check**: OAuth2-Proxy includes an init container that waits for Keycloak to be ready
- **Object Storage Secrets**: Credentials are automatically injected from OpenTofu outputs

## Troubleshooting

### APL Jobs Not Completing
```bash
kubectl get jobs --all-namespaces
kubectl logs -n <namespace> job/<job-name>
```

### NodeBalancer Issues
Check the NodeBalancer was created:
```bash
linode-cli nodebalancers list
```

### Access APL Logs
```bash
kubectl logs -n <namespace> -l app=apl
```

## Resources

- [APL Documentation](https://otomi.io/docs/)
- [KServe Documentation](https://kserve.github.io/)
- [Knative Documentation](https://knative.dev/docs/)
- [Linode Object Storage](https://www.linode.com/docs/products/storage/object-storage/)
