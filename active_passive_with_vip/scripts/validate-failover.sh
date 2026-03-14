#!/bin/bash

set -euo pipefail

echo "========================================="
echo "Validating VLAN VIP failover"
echo "========================================="

HOST_01_IP=$(tofu output -raw host_01_public_ip)
HOST_02_IP=$(tofu output -raw host_02_public_ip)
VLAN_VIP=$(tofu output -raw shared_vlan_vip)

SSH_KEY="/tmp/id_rsa"
SSH_OPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "${SSH_KEY}")

run_ssh() {
  local host="$1"
  local cmd="$2"
  ssh "${SSH_OPTS[@]}" root@"${host}" "${cmd}"
}

echo "[1/6] BGP route visibility"
run_ssh "${HOST_01_IP}" "vtysh -c 'show bgp ipv4 unicast ${VLAN_VIP}/32' || true"
run_ssh "${HOST_02_IP}" "vtysh -c 'show bgp ipv4 unicast ${VLAN_VIP}/32' || true"

echo "[2/6] VIP owner before failover"
run_ssh "${HOST_01_IP}" "ip -4 a show dev eth2 | grep -E '${VLAN_VIP}/32|inet ' || true"
run_ssh "${HOST_02_IP}" "ip -4 a show dev eth2 | grep -E '${VLAN_VIP}/32|inet ' || true"

echo "[3/6] Stop FRR on primary"
run_ssh "${HOST_01_IP}" "systemctl stop frr"
sleep 4

echo "[4/6] VIP owner after failover"
run_ssh "${HOST_01_IP}" "ip -4 a show dev eth2 | grep -E '${VLAN_VIP}/32|inet ' || true"
run_ssh "${HOST_02_IP}" "ip -4 a show dev eth2 | grep -E '${VLAN_VIP}/32|inet ' || true"

echo "[5/6] Connectivity probe"
ping -c 4 "${VLAN_VIP}" || true

echo "[6/6] Restore FRR on primary"
run_ssh "${HOST_01_IP}" "systemctl start frr"

echo "========================================="
echo "Validation completed"
echo "========================================="
