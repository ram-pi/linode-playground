#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

echo "========================================="
echo "Starting VPC Dual Stack Demo"
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

tofu init

tofu apply -auto-approve

KEY_PATH="$(tofu output -raw ssh_private_key_path)"
VM1_PUBLIC_IP="$(tofu output -raw vm1_public_ipv4)"
VM2_PUBLIC_IP="$(tofu output -raw vm2_public_ipv4)"
VM1_VPC_IPV4="$(tofu output -raw vm1_vpc_ipv4)"
VM2_VPC_IPV4="$(tofu output -raw vm2_vpc_ipv4)"
SUBNET_IPV6_RANGE="$(tofu output -raw vpc_subnet_ipv6_allocated_range)"

SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"
SSH_VM1="ssh ${SSH_OPTS} -i ${KEY_PATH} root@${VM1_PUBLIC_IP}"
SSH_VM2="ssh ${SSH_OPTS} -i ${KEY_PATH} root@${VM2_PUBLIC_IP}"

wait_for_ssh() {
  local host="$1"
  local attempts=30
  local delay=10

  for i in $(seq 1 "$attempts"); do
    if ssh ${SSH_OPTS} -i "${KEY_PATH}" "root@${host}" "echo ready" >/dev/null 2>&1; then
      return 0
    fi
    echo "Waiting for SSH on ${host} (${i}/${attempts})..."
    sleep "$delay"
  done

  return 1
}

echo "Waiting for SSH access on both VMs..."
wait_for_ssh "${VM1_PUBLIC_IP}"
wait_for_ssh "${VM2_PUBLIC_IP}"

echo ""
echo "Running connectivity tests..."
echo "- IPv4 ping: vm1 -> vm2 (${VM2_VPC_IPV4})"
${SSH_VM1} "ping -c 4 ${VM2_VPC_IPV4}"

echo "- IPv4 ping: vm2 -> vm1 (${VM1_VPC_IPV4})"
${SSH_VM2} "ping -c 4 ${VM1_VPC_IPV4}"

VM1_VPC_DEV="$(${SSH_VM1} "ip route get ${VM2_VPC_IPV4} | awk '{for(i=1;i<=NF;i++) if(\$i==\"dev\") {print \$(i+1); exit}}'")"
VM2_VPC_DEV="$(${SSH_VM2} "ip route get ${VM1_VPC_IPV4} | awk '{for(i=1;i<=NF;i++) if(\$i==\"dev\") {print \$(i+1); exit}}'")"

VM1_VPC_IPV6="$(${SSH_VM1} "ip -6 -o addr show dev ${VM1_VPC_DEV} scope global | awk '/inet6/ {print \$4}' | head -n1 | cut -d/ -f1")"
VM2_VPC_IPV6="$(${SSH_VM2} "ip -6 -o addr show dev ${VM2_VPC_DEV} scope global | awk '/inet6/ {print \$4}' | head -n1 | cut -d/ -f1")"

if [ -n "${VM1_VPC_IPV6}" ] && [ -n "${VM2_VPC_IPV6}" ]; then
  echo "- IPv6 subnet range allocated by Linode: ${SUBNET_IPV6_RANGE}"
  echo "- Detected vm1 VPC IPv6: ${VM1_VPC_IPV6}"
  echo "- Detected vm2 VPC IPv6: ${VM2_VPC_IPV6}"
  echo "- IPv6 ping: vm1 -> vm2"
  ${SSH_VM1} "ping -6 -c 4 ${VM2_VPC_IPV6}"
  echo "- IPv6 ping: vm2 -> vm1"
  ${SSH_VM2} "ping -6 -c 4 ${VM1_VPC_IPV6}"
else
  echo "Warning: IPv6 VPC addresses were not detected on one or both VMs."
  echo "This can happen if IPv6 VPC is not enabled for the account/region yet."
fi

echo ""
echo "========================================="
echo "Deployment complete"
echo "========================================="
echo ""
echo "SSH vm1: $(tofu output -raw ssh_command_vm1)"
echo "SSH vm2: $(tofu output -raw ssh_command_vm2)"
echo "VPC subnet IPv6 allocated range: ${SUBNET_IPV6_RANGE}"
