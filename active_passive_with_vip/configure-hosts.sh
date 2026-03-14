#!/bin/bash

set -e

echo "========================================="
echo "Configuring FRR/BGP on Active-Passive Nodes"
echo "========================================="
echo ""

if ! command -v lin >/dev/null 2>&1; then
    echo "Error: lin CLI is required for IP sharing."
    echo "Install with: pipx install linode-cli"
    exit 1
fi

if ! command -v ansible-playbook >/dev/null 2>&1; then
    echo "Error: ansible-playbook not found."
    echo "Install with: pipx install ansible"
    exit 1
fi

ENABLE_KEEPALIVED="${ENABLE_KEEPALIVED:-false}"

HOST_01_IP=$(tofu output -raw host_01_public_ip)
HOST_02_IP=$(tofu output -raw host_02_public_ip)

wait_for_ssh() {
    local ip="$1"
    local attempts=0
    local max_attempts=60

    echo "Waiting for SSH on ${ip}..."
    until ssh -q \
        -o BatchMode=yes \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout=5 \
        -i /tmp/id_rsa \
        root@"${ip}" exit; do
        attempts=$((attempts + 1))
        if [ "${attempts}" -ge "${max_attempts}" ]; then
            echo "Error: SSH to ${ip} failed after ${max_attempts} attempts."
            exit 1
        fi
        sleep 5
    done
    echo "SSH reachable on ${ip}"
}

wait_for_ssh "${HOST_01_IP}"
wait_for_ssh "${HOST_02_IP}"

echo ""
echo "Generating Ansible inventory..."
tofu output -raw ansible_inventory > ansible/inventory.yml

echo "Running Ansible FRR playbook..."
cd ansible
ANSIBLE_CONFIG=./ansible.cfg \
ANSIBLE_STDOUT_CALLBACK=default \
ANSIBLE_CALLBACK_RESULT_FORMAT=yaml \
ansible-playbook -i inventory.yml playbook.yml --extra-vars "dc_id=$(tofu output -raw bgp_dc_id) enable_keepalived=${ENABLE_KEEPALIVED}"
cd ..

echo ""
echo "========================================="
echo "FRR/BGP configuration complete"
echo "========================================="
echo ""
echo "Validation commands:"
tofu output -raw test_commands
