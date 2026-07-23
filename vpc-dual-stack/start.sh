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
VM3_PUBLIC_IP="$(tofu output -raw vm3_public_ipv4)"
VM1_VPC_IPV4="$(tofu output -raw vm1_vpc_ipv4)"
VM2_VPC_IPV4="$(tofu output -raw vm2_vpc_ipv4)"
VM3_VPC_IPV4="$(tofu output -raw vm3_vpc_ipv4)"
SUBNET_IPV6_RANGE="$(tofu output -raw vpc_subnet_ipv6_allocated_range)"

SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"
PUBLIC_IPS=("${VM1_PUBLIC_IP}" "${VM2_PUBLIC_IP}" "${VM3_PUBLIC_IP}")
VPC_IPS=("${VM1_VPC_IPV4}" "${VM2_VPC_IPV4}" "${VM3_VPC_IPV4}")
HOST_NAMES=("vm1" "vm2" "vm3")

ssh_run() {
  local index="$1"
  local command="$2"
  ssh ${SSH_OPTS} -i "${KEY_PATH}" "root@${PUBLIC_IPS[$index]}" "${command}"
}

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

echo "Waiting for SSH access on all VMs..."
for host in "${PUBLIC_IPS[@]}"; do
  wait_for_ssh "${host}"
done

echo ""
echo "Running connectivity tests..."
for i in 0 1 2; do
  for j in 0 1 2; do
    if [ "$i" -ge "$j" ]; then
      continue
    fi

    echo "- IPv4 ping: ${HOST_NAMES[$i]} -> ${HOST_NAMES[$j]} (${VPC_IPS[$j]})"
    ssh_run "$i" "ping -c 4 ${VPC_IPS[$j]}"

    echo "- IPv4 ping: ${HOST_NAMES[$j]} -> ${HOST_NAMES[$i]} (${VPC_IPS[$i]})"
    ssh_run "$j" "ping -c 4 ${VPC_IPS[$i]}"
  done
done

VM_VPC_DEVS=(
  "$(ssh_run 0 "ip route get ${VPC_IPS[1]} | awk '{for(i=1;i<=NF;i++) if(\$i==\"dev\") {print \$(i+1); exit}}'")"
  "$(ssh_run 1 "ip route get ${VPC_IPS[0]} | awk '{for(i=1;i<=NF;i++) if(\$i==\"dev\") {print \$(i+1); exit}}'")"
  "$(ssh_run 2 "ip route get ${VPC_IPS[0]} | awk '{for(i=1;i<=NF;i++) if(\$i==\"dev\") {print \$(i+1); exit}}'")"
)

VM_VPC_IPV6S=(
  "$(ssh_run 0 "ip -6 -o addr show dev ${VM_VPC_DEVS[0]} scope global | awk '/inet6/ {print \$4}' | head -n1 | cut -d/ -f1")"
  "$(ssh_run 1 "ip -6 -o addr show dev ${VM_VPC_DEVS[1]} scope global | awk '/inet6/ {print \$4}' | head -n1 | cut -d/ -f1")"
  "$(ssh_run 2 "ip -6 -o addr show dev ${VM_VPC_DEVS[2]} scope global | awk '/inet6/ {print \$4}' | head -n1 | cut -d/ -f1")"
)

if [ -n "${VM_VPC_IPV6S[0]}" ] && [ -n "${VM_VPC_IPV6S[1]}" ] && [ -n "${VM_VPC_IPV6S[2]}" ]; then
  echo "- IPv6 subnet range allocated by Linode: ${SUBNET_IPV6_RANGE}"
  echo "- Detected vm1 VPC IPv6: ${VM_VPC_IPV6S[0]}"
  echo "- Detected vm2 VPC IPv6: ${VM_VPC_IPV6S[1]}"
  echo "- Detected vm3 VPC IPv6: ${VM_VPC_IPV6S[2]}"

  for i in 0 1 2; do
    for j in 0 1 2; do
      if [ "$i" -ge "$j" ]; then
        continue
      fi

      echo "- IPv6 ping: ${HOST_NAMES[$i]} -> ${HOST_NAMES[$j]}"
      ssh_run "$i" "ping -6 -c 4 ${VM_VPC_IPV6S[$j]}"

      echo "- IPv6 ping: ${HOST_NAMES[$j]} -> ${HOST_NAMES[$i]}"
      ssh_run "$j" "ping -6 -c 4 ${VM_VPC_IPV6S[$i]}"
    done
  done
else
  echo "Warning: IPv6 VPC addresses were not detected on one or more VMs."
  echo "This can happen if IPv6 VPC is not enabled for the account/region yet."
fi

echo ""
echo "========================================="
echo "Deployment complete"
echo "========================================="
echo ""
echo "SSH vm1: $(tofu output -raw ssh_command_vm1)"
echo "SSH vm2: $(tofu output -raw ssh_command_vm2)"
echo "SSH vm3: $(tofu output -raw ssh_command_vm3)"
echo "VPC subnet IPv6 allocated range: ${SUBNET_IPV6_RANGE}"
