locals {
  host_01_public_ip = tolist(linode_instance.host_01.ipv4[*])[0]
  host_02_public_ip = tolist(linode_instance.host_02.ipv4[*])[0]
  #   host_01_private_ip = tolist(linode_instance.host_01.ipv4[*])[1]
  #   host_02_private_ip = tolist(linode_instance.host_02.ipv4[*])[1]
  host_03_public_ip = tolist(linode_instance.host_03.ipv4[*])[0]
  host_04_public_ip = tolist(linode_instance.host_04.ipv4[*])[0]

  lelastic_unit_file = {
    primary = <<-EOF
        [Unit]
        Description= Lelastic
        After=network-online.target
        Wants=network-online.target

        [Service]
        Type=simple
        ExecStart=/usr/local/bin/lelastic -dcid ${local.dc_id_map[local.region]} -primary &
        ExecReload=/bin/kill -s HUP $MAINPID

        [Install]
        WantedBy=multi-user.target
    EOF

    secondary = <<-EOF
        [Unit]
        Description= Lelastic
        After=network-online.target
        Wants=network-online.target

        [Service]
        Type=simple
        ExecStart=/usr/local/bin/lelastic -dcid ${local.dc_id_map[local.region]} -secondary &
        ExecReload=/bin/kill -s HUP $MAINPID

        [Install]
        WantedBy=multi-user.target
    EOF
  }
}

output "host_01_public_ip" {
  value       = local.host_01_public_ip
  description = "Public IP of host_01"
}

output "host_02_public_ip" {
  value       = local.host_02_public_ip
  description = "Public IP of host_02"
}

## SSH Connection Command
output "ssh_command" {
  value       = <<-EOF
    ssh -i ${local_file.private_key.filename} root@${local.host_01_public_ip}
    ssh -i ${local_file.private_key.filename} root@${local.host_02_public_ip}
    # lish connection:
    ssh -t ${data.linode_profile.me.username}@lish-${local.region}.linode.com ${linode_instance.host_01.label}
    ssh -t ${data.linode_profile.me.username}@lish-${local.region}.linode.com ${linode_instance.host_02.label}
  EOF
  description = "SSH command to connect to the VM"
}

## ssh root password
output "ssh_root_password" {
  value       = <<-EOF
    Root Password: ${random_password.root_password.result}
  EOF
  description = "Root password for SSH access"
  sensitive   = true
}

## netplan config for host_01
output "netplan_config_host_01" {
  value       = <<-EOF
    network:
      version: 2
      renderer: networkd
      ethernets:
        eth0:
          dhcp4: yes
        eth1:
          addresses:
            - ${local.vlan_address_map["host_01"]}
        lo:
          match:
            name: lo
          addresses:
            - ${local.host_01_public_ip}/32
   EOF
  description = "Netplan configuration for host_01 with VLAN"
}

## netplan config for host_02
output "netplan_config_host_02" {
  value       = <<-EOF
    network:
      version: 2
      renderer: networkd
      ethernets:
        eth0:
          dhcp4: yes
        eth1:
          addresses:
            - ${local.vlan_address_map["host_02"]}
        lo:
          match:
            name: lo
          addresses:
            - ${local.host_01_public_ip}/32
   EOF
  description = "Netplan configuration for host_02 with VLAN"
}

## scp command to copy files
output "scp_command" {
  value = join("\n", [
    "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${local_file.private_key.filename} 01-netcfg-host01.yaml root@${local.host_01_public_ip}:/etc/netplan/01-netcfg.yaml",
    "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${local_file.private_key.filename} 01-netcfg-host02.yaml root@${local.host_02_public_ip}:/etc/netplan/01-netcfg.yaml"
  ])
  description = "SCP command to copy files to the instances"
}

## netplan apply command
output "netplan_apply_command" {
  value = join("\n", [
    "ssh -n -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${local_file.private_key.filename} root@${local.host_01_public_ip} 'chmod 600 /etc/netplan/01-netcfg.yaml && netplan apply'",
    "ssh -n -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ${local_file.private_key.filename} root@${local.host_02_public_ip} 'chmod 600 /etc/netplan/01-netcfg.yaml && netplan apply'"
  ])
  description = "Command to apply netplan configuration inside the instances"
}

## lelastic unit file content - primary node
output "lelastic_unit_file" {
  value       = local.lelastic_unit_file
  description = "Systemd unit file content for lelastic service"
}

## lelastic unit file outputs for local file generation
output "lelastic_unit_file_primary" {
  value       = local.lelastic_unit_file.primary
  description = "Systemd unit file for lelastic primary node"
}

output "lelastic_unit_file_secondary" {
  value       = local.lelastic_unit_file.secondary
  description = "Systemd unit file for lelastic secondary node"
}

## scp command to copy lelastic unit files
output "lelastic_scp_command" {
  value = join("\n", [
    "scp -i ${local_file.private_key.filename} lelastic-primary.service root@${local.host_01_public_ip}:/etc/systemd/system/lelastic.service",
    "scp -i ${local_file.private_key.filename} lelastic-secondary.service root@${local.host_02_public_ip}:/etc/systemd/system/lelastic.service"
  ])
  description = "SCP command to copy lelastic unit files to the instances"
}
output "linode_cli_share_ip_command" {
  value       = <<-EOF
    lin networking ip-share --ips ${local.host_01_public_ip} --linode_id ${linode_instance.host_02.id}
  EOF
  description = "linode-cli command to share public IP from host_01 to host_02"
}

## lelastic installation command for both hosts
output "lelastic_install_command" {
  value = join("\n", [
    "ssh -n -i ${local_file.private_key.filename} root@${local.host_01_public_ip} 'curl -LO https://github.com/linode/lelastic/releases/download/v0.2.0/lelastic.gz && gunzip lelastic.gz && chmod 755 lelastic && mv lelastic /usr/local/bin/'",
    "ssh -n -i ${local_file.private_key.filename} root@${local.host_02_public_ip} 'curl -LO https://github.com/linode/lelastic/releases/download/v0.2.0/lelastic.gz && gunzip lelastic.gz && chmod 755 lelastic && mv lelastic /usr/local/bin/'"
  ])
  description = "Command to install lelastic on both hosts"
}

## lelastic service setup command for both hosts
output "lelastic_service_setup_command" {
  value = join("\n", [
    "ssh -n -i ${local_file.private_key.filename} root@${local.host_01_public_ip} 'chmod 644 /etc/systemd/system/lelastic.service && systemctl daemon-reload && systemctl enable lelastic && systemctl start lelastic'",
    "ssh -n -i ${local_file.private_key.filename} root@${local.host_02_public_ip} 'chmod 644 /etc/systemd/system/lelastic.service && systemctl daemon-reload && systemctl enable lelastic && systemctl start lelastic'"
  ])
  description = "Command to set up and start lelastic service on both hosts"
}

# testing connectivity command
output "connectivity_test_command" {
  value       = <<-EOF
    ping ${local.host_01_public_ip}
    # from another shell
    lin linodes shutdown ${linode_instance.host_01.id}
    EOF
  description = "Command to test connectivity to the shared IP"
}

# nginx curl commands
output "nginx_curl_commands" {
  value       = <<-EOF
    curl http://${local.host_03_public_ip}
    curl http://${local.host_04_public_ip}
    EOF
  description = "Curl commands to test nginx on both hosts"
}
