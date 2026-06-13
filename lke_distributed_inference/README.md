# LKE Distributed Inference with Karmada + KubeRay

This demo provisions three **LKE Standard** clusters and deploys a multi-cluster inference stack for **Mistral-7B-v0.3** with LiteLLM as an optional central gateway.

- Region 1: `gb-lon` (Karmada control-plane host — no GPU)
- Region 2: `de-fra-2` (Karmada member — GPU inference)
- Region 3: `us-sea` (Karmada member — GPU inference)
- Per Karmada host cluster (gb-lon):
  - `3 x g6-standard-4` (standard pool only)
- Per inference cluster (`de-fra-2` and `us-sea`):
  - `3 x g6-standard-4`
  - `1 x g2-gpu-rtx4000a1-m`

The goal is to demonstrate cluster provisioning with OpenTofu and manual multi-cluster model serving through Karmada + KubeRay, with centralized OpenAI-compatible access through LiteLLM.

## Architecture overview

![architecture](distributed-inference-architecture.excalidraw.svg)

The diagram illustrates the following flow:
1. **Client Requests**: Originating from the user's laptop, hitting LiteLLM in `gb-lon` or a direct regional endpoint for validation.
2. **Traffic Routing**: LiteLLM routes by model alias to regional **Secure Gateways** (NodeBalancers) in `de-fra-2` and `us-sea`.
3. **Multi-Cluster Orchestration**: **Karmada** (hosted in `gb-lon`) propagates KubeRay resources and inference configurations to member clusters.
4. **GPU Inference**: **KubeRay** manages Ray Clusters on GPU-enabled nodes, serving **Mistral-7B-v0.3**.
5. **Location Visibility**: Each regional gateway adds `X-Serving-Region` and `X-Serving-Cluster` response headers so clients can identify which location served the request.
6. **Access Control**: Regional gateways allow only the user's laptop CIDR and discovered LiteLLM egress CIDRs from `gb-lon`; LiteLLM allows only the user's laptop CIDR. LoadBalancer access is restricted with Kubernetes source ranges and Linode firewall ACL annotations.


## Quick start

```bash
export LINODE_TOKEN="<your-linode-token>"
cp terraform.tfvars.example terraform.tfvars

./start.sh
```

After provisioning finishes, continue with [MANUAL_DEPLOYMENT.md](MANUAL_DEPLOYMENT.md) for:

- Karmada bootstrap and cluster join
- KubeRay installation on both clusters through Karmada
- Linode Cloud Firewall controller installation for the NodeBalancer gateway
- RayService deployment for Mistral-7B-v0.3
- Regional NodeBalancer exposure with laptop + LiteLLM egress allowlisting
- LiteLLM deployment on the `gb-lon` control-plane cluster

For gateway usage after deployment, see [LITELLM.md](LITELLM.md). A local static curl simulator is available at [ui/curl-simulator.html](ui/curl-simulator.html).

## Teardown

```bash
./shutdown.sh
```
