#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

echo "========================================="
echo "Starting VPC IPv6 + IPv4 Dual Stack Demo"
echo "========================================="

if [ -z "${LINODE_TOKEN:-}" ]; then
  echo "Error: LINODE_TOKEN environment variable is not set"
  echo "  export LINODE_TOKEN='your-token-here'"
  exit 1
fi

if ! command -v tofu >/dev/null 2>&1; then
  echo "Error: tofu (OpenTofu) is not installed"
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is not installed"
  exit 1
fi

tofu init -upgrade
tofu apply -auto-approve

KEY_PATH="$(tofu output -raw ssh_private_key_path)"
PUBLIC_IPS_JSON="$(tofu output -json vm_public_ipv4)"
VPC_IPS_JSON="$(tofu output -json vm_vpc_ipv4)"

VM1_PUBLIC_IP="$(jq -r '.vm1' <<<"${PUBLIC_IPS_JSON}")"
VM2_PUBLIC_IP="$(jq -r '.vm2' <<<"${PUBLIC_IPS_JSON}")"
VM1_VPC_IPV4="$(jq -r '.vm1' <<<"${VPC_IPS_JSON}")"
VM2_VPC_IPV4="$(jq -r '.vm2' <<<"${VPC_IPS_JSON}")"

SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"

wait_for_ssh() {
  local host="$1"
  echo "Waiting for SSH on ${host}..."
  for i in $(seq 1 30); do
    if ssh ${SSH_OPTS} -i "${KEY_PATH}" "root@${host}" "echo ready" >/dev/null 2>&1; then
      return 0
    fi
    echo "  attempt ${i}/30..."
    sleep 10
  done
  return 1
}

echo ""
wait_for_ssh "${VM1_PUBLIC_IP}"
wait_for_ssh "${VM2_PUBLIC_IP}"

echo ""
echo "VM network configuration:"
for ip in "${VM1_PUBLIC_IP}" "${VM2_PUBLIC_IP}"; do
  ssh ${SSH_OPTS} -i "${KEY_PATH}" "root@${ip}" "hostname; ip -brief addr" || true
  echo ""
done

# Global IPv6 addresses are SLAAC-generated, so they can only be read from the hosts.
VM1_VPC_IPV6="$(ssh ${SSH_OPTS} -i "${KEY_PATH}" "root@${VM1_PUBLIC_IP}" "ip -6 -o addr show scope global | awk '{print \$4}' | cut -d/ -f1 | head -n1")"
VM2_VPC_IPV6="$(ssh ${SSH_OPTS} -i "${KEY_PATH}" "root@${VM2_PUBLIC_IP}" "ip -6 -o addr show scope global | awk '{print \$4}' | cut -d/ -f1 | head -n1")"

echo "Connectivity tests over the VPC:"
echo "- IPv4: vm1 -> vm2 (${VM2_VPC_IPV4})"
ssh ${SSH_OPTS} -i "${KEY_PATH}" "root@${VM1_PUBLIC_IP}" "ping -c 4 ${VM2_VPC_IPV4}" || true

echo "- IPv4: vm2 -> vm1 (${VM1_VPC_IPV4})"
ssh ${SSH_OPTS} -i "${KEY_PATH}" "root@${VM2_PUBLIC_IP}" "ping -c 4 ${VM1_VPC_IPV4}" || true

if [ -n "${VM1_VPC_IPV6}" ] && [ -n "${VM2_VPC_IPV6}" ]; then
  echo "- IPv6: vm1 -> vm2 (${VM2_VPC_IPV6})"
  ssh ${SSH_OPTS} -i "${KEY_PATH}" "root@${VM1_PUBLIC_IP}" "ping -6 -c 4 ${VM2_VPC_IPV6}" || true

  echo "- IPv6: vm2 -> vm1 (${VM1_VPC_IPV6})"
  ssh ${SSH_OPTS} -i "${KEY_PATH}" "root@${VM2_PUBLIC_IP}" "ping -6 -c 4 ${VM1_VPC_IPV6}" || true
else
  echo "Warning: no global IPv6 address detected on one or both VMs."
fi

echo ""
echo "========================================="
echo "Deployment complete"
echo "========================================="
echo "VPC label:         $(tofu output -raw vpc_label)"
echo "VPC id:            $(tofu output -raw vpc_id)"
echo "VPC IPv6 range:    $(tofu output -raw vpc_ipv6_range)"
echo "Subnet id:         $(tofu output -raw subnet_id)"
echo "Subnet IPv4 CIDR:  $(tofu output -raw subnet_ipv4_cidr)"
echo "Subnet IPv6 range: $(tofu output -raw subnet_ipv6_range)"
echo "vm1: vpc ${VM1_VPC_IPV4} | public ${VM1_PUBLIC_IP} | ipv6 ${VM1_VPC_IPV6:-n/a}"
echo "vm2: vpc ${VM2_VPC_IPV4} | public ${VM2_PUBLIC_IP} | ipv6 ${VM2_VPC_IPV6:-n/a}"
echo ""
tofu output ssh_commands
