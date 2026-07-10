# LKE with Karpenter

A self-contained demo that provisions a small [Linode LKE](https://www.linode.com/products/kubernetes/) Standard cluster in `gb-lon` and walks through installing the [Linode Karpenter provider](https://github.com/linode/karpenter-provider-linode) and the [Linode Cloud Firewall Controller](https://github.com/linode/cloud-firewall-controller).

> **Alpha software warning**
> The Linode Karpenter provider is currently **alpha** and under active development. It is not suitable for production. Use it only in development/test environments and expect breaking changes.

---

## Architecture

![Architecture](diagrams/architecture.excalidraw.svg)

The demo has two phases:

1. **Infrastructure (`start.sh`)**: OpenTofu provisions a 3-node LKE Standard cluster (`g6-standard-2`) in `gb-lon` and writes a local `kubeconfig.yaml`.
2. **Kubernetes setup (`MANUAL_DEPLOYMENT.md`)**: You install the Cloud Firewall Controller, the Karpenter CRD and controller, a default NodePool, and run a scale-up/down workload.

Karpenter runs in **LKE mode** (default): when pods are unschedulable, the provider creates count-1 LKE NodePools to host them; when nodes are empty, Karpenter consolidates them away.

---

## Components

| Component | Purpose |
|-----------|---------|
| `start.sh` / `shutdown.sh` | Provision/destroy the LKE cluster |
| OpenTofu (`tofu`) | Infrastructure-as-code for LKE |
| Cloud Firewall Controller | Applies a managed Cloud Firewall to every cluster node |
| Karpenter provider for Linode | Watches pending pods and autoprovisions LKE NodePools |
| Default NodePool | `LinodeNodeClass` + `NodePool` with a 32-CPU PoC cap |
| `inflate` deployment | Pause workload used to trigger scale-up/down |

---

## Prerequisites

- Linode API token with Read/Write access.
- `tofu` (OpenTofu) — `brew install opentofu`
- `kubectl` — `brew install kubectl`
- `helm` — `brew install helm`
- `LINODE_TOKEN` exported as an environment variable.

---

## Quick Start

```bash
export LINODE_TOKEN="your-linode-api-token"

# 1. Provision the cluster
./start.sh

# 2. Follow the Kubernetes setup runbook
export KUBECONFIG="$PWD/kubeconfig.yaml"
cat MANUAL_DEPLOYMENT.md
```

`start.sh` checks for required tools, runs `tofu init` and `tofu apply -auto-approve`, waits for all nodes to be Ready, and prints the cluster details.

---

## Shutdown

```bash
./shutdown.sh
```

This prompts for confirmation before running `tofu destroy -auto-approve` and removes the local `kubeconfig.yaml`.

---

## References

- [Linode Karpenter Provider](https://github.com/linode/karpenter-provider-linode)
- [Linode Cloud Firewall Controller](https://github.com/linode/cloud-firewall-controller)
- [Karpenter Documentation](https://karpenter.sh/)
