locals {
  host_01_public_ip = tolist(linode_instance.host_01.ipv4[*])[0]
  host_02_public_ip = tolist(linode_instance.host_02.ipv4[*])[0]
  host_03_public_ip = tolist(linode_instance.host_03.ipv4[*])[0]
  host_01_vlan_ip   = split("/", local.vlan_address_map["host_01"])[0]
  host_02_vlan_ip   = split("/", local.vlan_address_map["host_02"])[0]
  host_03_vlan_ip   = split("/", local.vlan_address_map["host_03"])[0]
}

output "host_01_public_ip" {
  value       = local.host_01_public_ip
  description = "Public IPv4 of host_01"
}

output "host_02_public_ip" {
  value       = local.host_02_public_ip
  description = "Public IPv4 of host_02"
}

output "host_03_public_ip" {
  value       = local.host_03_public_ip
  description = "Public IPv4 of host_03 (VLAN test client)"
}

output "shared_vlan_vip" {
  value       = local.shared_vip
  description = "Shared VIP on VLAN"
}

output "ssh_command" {
  value       = <<-EOF
    ssh -i ${local_file.private_key.filename} root@${local.host_01_public_ip}
    ssh -i ${local_file.private_key.filename} root@${local.host_02_public_ip}
    ssh -i ${local_file.private_key.filename} root@${local.host_03_public_ip}
    ssh -t ${data.linode_profile.me.username}@lish-${local.region}.linode.com ${linode_instance.host_01.label}
    ssh -t ${data.linode_profile.me.username}@lish-${local.region}.linode.com ${linode_instance.host_02.label}
    ssh -t ${data.linode_profile.me.username}@lish-${local.region}.linode.com ${linode_instance.host_03.label}
  EOF
  description = "SSH and Lish connection commands"
}

output "ssh_root_password" {
  value       = "Root Password: ${random_password.root_password.result}"
  description = "Root password for both hosts"
  sensitive   = true
}

output "ansible_inventory" {
  value       = <<-EOF
    all:
      vars:
        ansible_user: root
        ansible_ssh_private_key_file: ${local_file.private_key.filename}
        ansible_ssh_common_args: '-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'

      children:
        frr_nodes:
          hosts:
            host_01:
              ansible_host: ${local.host_01_public_ip}
              host_name: ${linode_instance.host_01.label}
              node_role: primary
              vlan_ip: ${local.host_01_vlan_ip}
              peer_vlan_ip: ${local.host_02_vlan_ip}
              vlan_vip: ${local.shared_vip}
            host_02:
              ansible_host: ${local.host_02_public_ip}
              host_name: ${linode_instance.host_02.label}
              node_role: secondary
              vlan_ip: ${local.host_02_vlan_ip}
              peer_vlan_ip: ${local.host_01_vlan_ip}
              vlan_vip: ${local.shared_vip}
  EOF
  description = "Generated Ansible inventory for FRR configuration"
}

output "bgp_router_asn" {
  value       = 65001
  description = "Customer ASN used by FRR"
}

output "bgp_peer_asn" {
  value       = 65000
  description = "Akamai route server ASN"
}

output "bgp_dc_id" {
  value       = local.dc_id
  description = "Data center ID used in BGP peer IPv6 addresses"
}

output "test_commands" {
  value       = <<-EOF
    # verify BGP on both nodes
    ssh -i ${local_file.private_key.filename} root@${local.host_01_public_ip} 'vtysh -c "show bgp ipv4 unicast ${local.shared_vip}/32"'
    ssh -i ${local_file.private_key.filename} root@${local.host_02_public_ip} 'vtysh -c "show bgp ipv4 unicast ${local.shared_vip}/32"'

    # check VIP from each node
    ssh -i ${local_file.private_key.filename} root@${local.host_01_public_ip} 'ip -o -4 addr show | grep -E "${local.shared_vip}/32|${local.host_01_vlan_ip}/" || true'
    ssh -i ${local_file.private_key.filename} root@${local.host_02_public_ip} 'ip -o -4 addr show | grep -E "${local.shared_vip}/32|${local.host_02_vlan_ip}/" || true'

    # test VIP reachability from third VM on VLAN
    ssh -i ${local_file.private_key.filename} root@${local.host_03_public_ip} 'ping -c 4 ${local.shared_vip}'
    ssh -i ${local_file.private_key.filename} root@${local.host_03_public_ip} 'bash -lc "command -v curl >/dev/null && curl -m 3 http://${local.shared_vip} || echo curl-not-installed"'

    # fail over by stopping FRR on primary
    ssh -i ${local_file.private_key.filename} root@${local.host_01_public_ip} 'systemctl stop frr'
    ssh -i ${local_file.private_key.filename} root@${local.host_03_public_ip} 'ping -c 4 ${local.shared_vip}'
    ssh -i ${local_file.private_key.filename} root@${local.host_01_public_ip} 'systemctl start frr'
  EOF
  description = "Basic validation and failover commands"
}
