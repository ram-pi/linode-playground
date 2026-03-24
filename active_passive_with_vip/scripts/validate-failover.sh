#!/bin/bash

set -euo pipefail

echo "========================================="
echo "Validating VLAN VIP failover"
echo "========================================="

HOST_01_IP=$(tofu output -raw host_01_public_ip)
HOST_02_IP=$(tofu output -raw host_02_public_ip)
HOST_03_IP=$(tofu output -raw host_03_public_ip)
VLAN_VIP=$(tofu output -raw shared_vlan_vip)
HOST_01_VLAN_IP=$(tofu output -raw host_01_vlan_ip)
HOST_02_VLAN_IP=$(tofu output -raw host_02_vlan_ip)

SSH_KEY="/tmp/id_rsa"
SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "${SSH_KEY}")

run_ssh() {
  local host="$1"
  local cmd="$2"
  ssh "${SSH_OPTS[@]}" root@"${host}" "${cmd}"
}

detect_vlan_interface() {
  local host="$1"
  local vlan_ip="$2"
  run_ssh "${host}" "ip -o -4 addr show | awk '\$4 ~ /^${vlan_ip}\// {print \$2; exit}'"
}

echo "[1/7] Keepalived status"
run_ssh "${HOST_01_IP}" "systemctl is-active keepalived"
run_ssh "${HOST_02_IP}" "systemctl is-active keepalived"

IFACE_01=$(detect_vlan_interface "${HOST_01_IP}" "${HOST_01_VLAN_IP}")
IFACE_02=$(detect_vlan_interface "${HOST_02_IP}" "${HOST_02_VLAN_IP}")

if [[ -z "${IFACE_01}" || -z "${IFACE_02}" ]]; then
  echo "Error: could not detect VLAN interfaces for one or both failover nodes"
  exit 1
fi

echo "[2/7] VLAN interface detection"
echo "host_01 interface: ${IFACE_01}"
echo "host_02 interface: ${IFACE_02}"

echo "[3/7] VIP owner before failover"
run_ssh "${HOST_01_IP}" "ip -4 a show dev ${IFACE_01} | grep -E '${VLAN_VIP}/32|inet ' || true"
run_ssh "${HOST_02_IP}" "ip -4 a show dev ${IFACE_02} | grep -E '${VLAN_VIP}/32|inet ' || true"

echo "[4/7] Stop keepalived on primary"
run_ssh "${HOST_01_IP}" "systemctl stop keepalived"
sleep 4

echo "[5/7] VIP owner after failover"
run_ssh "${HOST_01_IP}" "ip -4 a show dev ${IFACE_01} | grep -E '${VLAN_VIP}/32|inet ' || true"
run_ssh "${HOST_02_IP}" "ip -4 a show dev ${IFACE_02} | grep -E '${VLAN_VIP}/32|inet ' || true"

echo "[6/7] Connectivity probe"
run_ssh "${HOST_03_IP}" "ping -c 4 ${VLAN_VIP}" || true

echo "[7/7] Restore keepalived on primary"
run_ssh "${HOST_01_IP}" "systemctl start keepalived"

echo "========================================="
echo "Validation completed"
echo "========================================="
