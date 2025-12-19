#!/bin/bash

set -e

echo "========================================="
echo "Deploying HAProxy Load Balancers"
echo "========================================="
echo ""

# Wait for SSH connectivity to HAProxy hosts
echo "Waiting for SSH connectivity to HAProxy hosts..."
HOST_01_IP=$(tofu output -raw host_01_public_ip)
HOST_02_IP=$(tofu output -raw host_02_public_ip)

for ip in "$HOST_01_IP" "$HOST_02_IP"; do
    echo "Waiting for SSH on $ip..."
    attempts=0
    max_attempts=60
    until ssh -q \
                        -o BatchMode=yes \
                        -o StrictHostKeyChecking=no \
                        -o UserKnownHostsFile=/dev/null \
                        -o ConnectTimeout=5 \
                        -i /tmp/id_rsa \
                        root@"$ip" exit; do
        attempts=$((attempts+1))
        if [ "$attempts" -ge "$max_attempts" ]; then
            echo "Error: Unable to establish SSH to $ip after $max_attempts attempts."
            exit 1
        fi
        sleep 5
    done
    echo "SSH reachable on $ip"
done

# Verify Ansible is installed
if ! command -v ansible-playbook &> /dev/null; then
    echo "Error: ansible-playbook not found. Please install Ansible first:"
    echo "  pipx install ansible"
    echo "  or"
    echo "  brew install ansible"
    exit 1
fi

# Generate the Ansible inventory from Terraform output
echo "Generating Ansible inventory from Terraform outputs..."
tofu output -raw ansible_inventory > ansible/inventory.yml

# Run the Ansible playbook
echo "Running Ansible playbook to install and configure HAProxy..."
cd ansible
ansible-playbook -i inventory.yml playbook.yml
cd ..

echo ""
echo "========================================="
echo "HAProxy Deployment Completed!"
echo "========================================="
echo ""
echo "HAProxy Stats Available:"
echo "  http://$HOST_01_IP:8404/stats"
echo "  http://$HOST_02_IP:8404/stats"
echo ""
echo "Test the load balancer:"
echo "  curl http://$HOST_01_IP"
echo ""
echo "The load balancer will distribute traffic between:"
echo "  - host_03 (10.10.100.3)"
echo "  - host_04 (10.10.100.4)"
echo ""
