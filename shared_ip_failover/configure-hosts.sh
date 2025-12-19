#!/bin/bash

set -e  # Exit on error

echo "========================================="
echo "Configuring Hosts"
echo "========================================="
echo ""

# Apply netplan configuration on both hosts
echo "Applying netplan configuration on both hosts..."
tofu output -raw netplan_config_host_01 > 01-netcfg-host01.yaml
tofu output -raw netplan_config_host_02 > 01-netcfg-host02.yaml
tofu output -raw scp_command | bash
tofu output -raw netplan_apply_command | bash

echo "========================================="
echo "Netplan configuration applied!"
echo "========================================="

# Install lelastic on both hosts
echo "Installing lelastic on both hosts..."
tofu output -raw lelastic_install_command | bash
echo ""

# Generate lelastic systemd unit files
echo "Generating lelastic systemd unit files..."
tofu output -raw lelastic_unit_file_primary > lelastic-primary.service
tofu output -raw lelastic_unit_file_secondary > lelastic-secondary.service

# Copy lelastic unit files to both hosts
echo "Copying lelastic unit files to both hosts..."
tofu output -raw lelastic_scp_command | bash

# Create and start lelastic systemd service on both hosts
echo "Setting up lelastic service on both hosts..."
tofu output -raw lelastic_service_setup_command | bash
echo ""

echo "========================================="
echo "Lelastic installation completed!"
echo "========================================="

# Final step: sharing the public IP address
echo "Sharing the public IP address of host_01 to host_02..."
tofu output -raw linode_cli_share_ip_command | bash
echo ""

echo "========================================="
echo "Public IP sharing completed!"
echo "To test, from your local machine, run:"
echo "$(tofu output -raw connectivity_test_command)"
echo "Then, poweroff host_01 to see failover in action."
echo "========================================="

# Nginx test instructions
echo ""
echo "To test nginx on both hosts, run the following commands from your local machine:"
echo "$(tofu output -raw nginx_curl_commands)"
echo ""

echo "========================================="
echo "Host Configuration Complete!"
echo "========================================="
