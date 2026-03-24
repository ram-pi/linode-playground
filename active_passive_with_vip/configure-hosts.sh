#!/bin/bash

set -euo pipefail

echo "========================================="
echo "Configuring Keepalived on Active-Passive Nodes"
echo "========================================="
echo ""

if ! command -v ansible-playbook >/dev/null 2>&1; then
    echo "Error: ansible-playbook not found."
    echo "Install with: pipx install ansible"
    exit 1
fi

HOST_01_IP=$(tofu output -raw host_01_public_ip)
HOST_02_IP=$(tofu output -raw host_02_public_ip)
HEALTHCHECK_URL="${HEALTHCHECK_URL:-}"

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

EXTRA_VARS=()
if [ -n "${HEALTHCHECK_URL}" ]; then
    echo "Using optional healthcheck_url: ${HEALTHCHECK_URL}"
    EXTRA_VARS+=(--extra-vars "healthcheck_url=${HEALTHCHECK_URL}")
fi

echo "Running Ansible Keepalived playbook..."
PLAYBOOK_CMD=(ansible-playbook -i ansible/inventory.yml ansible/playbook.yml)
if [ ${#EXTRA_VARS[@]} -gt 0 ]; then
    PLAYBOOK_CMD+=("${EXTRA_VARS[@]}")
fi
ANSIBLE_CONFIG=./ansible.cfg \
ANSIBLE_STDOUT_CALLBACK=default \
ANSIBLE_CALLBACK_RESULT_FORMAT=yaml \
"${PLAYBOOK_CMD[@]}"

echo ""
echo "========================================="
echo "Keepalived configuration complete"
echo "========================================="
echo ""
echo "Validation commands:"
tofu output -raw test_commands
