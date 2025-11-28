locals {
  gateway_site_1_ip = tolist(linode_instance.gateway-site-1.ipv4[*])[0]
  gateway_site_2_ip = tolist(linode_instance.gateway-site-2.ipv4[*])[0]
}

# # SSH Connection Command
output "ssh_command" {
  value       = <<-EOT
    # Gateway SSH Commands
    ssh -i ${local_file.private_key.filename} root@${local.gateway_site_1_ip}
    ssh -i ${local_file.private_key.filename} root@${local.gateway_site_2_ip}

    # Host SSH Commands (Internal LAN IPs)
    ssh root@10.10.1.3
    ssh root@10.10.2.3

    #  Jump through Gateway to Hosts
    ssh -o ProxyCommand="ssh -W %h:%p -i ${local_file.private_key.filename} root@${local.gateway_site_1_ip}" -i ${local_file.private_key.filename} root@10.10.1.3
    ssh -o ProxyCommand="ssh -W %h:%p -i ${local_file.private_key.filename} root@${local.gateway_site_2_ip}" -i ${local_file.private_key.filename} root@10.10.2.3
  EOT
  description = "SSH command to connect to the VMs"
}

output "host_root_password" {
  value       = random_password.host_root_password.result
  description = "Root password for host-site-1 and host-site-2 instances"

  sensitive = true
}

output "ansible_host_ini" {
  value = <<-EOT
    [vpn_gateways]
    # Site 1 Gateway
    site_1  ansible_host=${local.gateway_site_1_ip} lan_interface=eth1  private_lan_ip=${local.gateway_1_internal_ip}  private_lan_subnet=${local.site_1_vlan_cidr}  vpn_ip=10.255.255.1/30

    # Site 2 Gateway
    site_2  ansible_host=${local.gateway_site_2_ip} lan_interface=eth1 private_lan_ip=${local.gateway_2_internal_ip}  private_lan_subnet=${local.site_2_vlan_cidr}  vpn_ip=10.255.255.2/30

    [site_1_hosts]
    # Set ansible_host to the PRIVATE IP (VLAN IP)
    site_1_host_01   ansible_host="${local.host_1_internal_ip}" private_ip="${local.host_1_internal_ip}/24"

    [site_2_hosts]
    # Set ansible_host to the PRIVATE IP (VLAN IP)
    site_2_host_01  ansible_host="${local.host_2_internal_ip}" private_ip="${local.host_2_internal_ip}/24"

    # --- JUMP CONFIGURATION ---
    # Tell Ansible: "To reach Site 1 Apps, jump through Site 1 Gateway"
    [site_1_hosts:vars]
    ansible_ssh_private_key_file=${local_file.private_key.filename}
    ansible_ssh_common_args='-o ProxyCommand="ssh -W %h:%p -i ${local_file.private_key.filename} root@${local.gateway_site_1_ip}"'
    remote_subnet=10.10.2.0/24
    local_gateway=10.10.1.2
    lan_interface=eth0

    # Tell Ansible: "To reach Site 2 Apps, jump through Site 2 Gateway"
    [site_2_hosts:vars]
    ansible_ssh_private_key_file=${local_file.private_key.filename}
    ansible_ssh_common_args='-o ProxyCommand="ssh -W %h:%p -i ${local_file.private_key.filename} root@${local.gateway_site_2_ip}"'
    remote_subnet=10.10.1.0/24
    local_gateway=10.10.2.2
    lan_interface=eth0
  EOT

  description = "Ansible inventory file content"
}
