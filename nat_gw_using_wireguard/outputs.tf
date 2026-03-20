output "topology_summary" {
  value = <<-EOT
  VPC: ${linode_vpc.main.label} (${linode_vpc_subnet.main.ipv4})
  NAT gateway VM: ${linode_instance.nat_gateway.label}
    - VPC IP: ${local.nat_gateway_ip}
    - Public access: enabled through nat_1_1 = any
    - Bootstrap roles: forward proxy + WireGuard server

  Private VM: ${linode_instance.private_vm.label}
    - VPC IP: ${local.private_vm_ip}
    - Public access: disabled (no nat_1_1, no public interface)
  EOT
}

output "nat_gateway_public_ip" {
  description = "Public IPv4 for the NAT gateway VM"
  value       = tolist(linode_instance.nat_gateway.ipv4)[0]
}

output "nat_gateway_vpc_ip" {
  description = "VPC IPv4 for the NAT gateway VM"
  value       = local.nat_gateway_ip
}

output "private_vm_vpc_ip" {
  description = "VPC IPv4 for the private VM"
  value       = local.private_vm_ip
}

output "ssh_nat_gateway" {
  description = "SSH command for NAT gateway"
  value       = "ssh -i ${local_file.private_key.filename} root@${tolist(linode_instance.nat_gateway.ipv4)[0]}"
}

output "ssh_private_via_jump" {
  description = "SSH to private VM through NAT gateway as jump host"
  value       = "ssh -i ${local_file.private_key.filename} -o IdentitiesOnly=yes -o ProxyCommand='ssh -i ${local_file.private_key.filename} -o IdentitiesOnly=yes -W %h:%p root@${tolist(linode_instance.nat_gateway.ipv4)[0]}' root@${local.private_vm_ip}"
}

output "nat_gateway_root_password" {
  description = "Root password for NAT gateway VM"
  value       = random_password.root_password.result
  sensitive   = true
}

output "private_vm_root_password" {
  description = "Root password for private VM"
  value       = random_password.root_password.result
  sensitive   = true
}

output "wireguard_bootstrap_commands" {
  description = "Commands to configure forward proxy bootstrap plus WireGuard egress"
  value       = <<-EOT
  # 1) Copy setup scripts to the NAT gateway and private VM
  scp -i ${local_file.private_key.filename} ./scripts/setup_forward_proxy.sh root@${tolist(linode_instance.nat_gateway.ipv4)[0]}:/root/
  scp -i ${local_file.private_key.filename} ./scripts/setup_wireguard_nat_gateway.sh root@${tolist(linode_instance.nat_gateway.ipv4)[0]}:/root/
  scp -i ${local_file.private_key.filename} -o ProxyCommand='ssh -i ${local_file.private_key.filename} -o IdentitiesOnly=yes -W %h:%p root@${tolist(linode_instance.nat_gateway.ipv4)[0]}' ./scripts/setup_wireguard_client.sh root@${local.private_vm_ip}:/root/

  # 2) Configure Squid on the NAT gateway for package/bootstrap egress inside the VPC
  ssh -i ${local_file.private_key.filename} root@${tolist(linode_instance.nat_gateway.ipv4)[0]} 'chmod +x /root/setup_forward_proxy.sh && /root/setup_forward_proxy.sh --listen-ip ${local.nat_gateway_ip} --allow-cidr ${local.vpc_cidr} --port 8080'

  # 3) Configure WireGuard server on the NAT gateway using the private VPC IP as endpoint
  ssh -i ${local_file.private_key.filename} root@${tolist(linode_instance.nat_gateway.ipv4)[0]} 'chmod +x /root/setup_wireguard_nat_gateway.sh && /root/setup_wireguard_nat_gateway.sh --wg-subnet ${local.wireguard_subnet} --server-address ${local.wireguard_server} --peer-address ${local.wireguard_client} --peer-allowed-ip 10.88.0.2/32 --endpoint ${local.nat_gateway_ip}'

  # 4) Copy the generated WireGuard client profile from the gateway to local disk, then to the private VM
  scp -i ${local_file.private_key.filename} root@${tolist(linode_instance.nat_gateway.ipv4)[0]}:/root/wg0-client1.conf /tmp/wg0-client1.conf
  scp -i ${local_file.private_key.filename} -o ProxyCommand='ssh -i ${local_file.private_key.filename} -o IdentitiesOnly=yes -W %h:%p root@${tolist(linode_instance.nat_gateway.ipv4)[0]}' /tmp/wg0-client1.conf root@${local.private_vm_ip}:/root/wg0.conf

  # 5) Install WireGuard on the private VM through the forward proxy, then bring the tunnel up
  ssh -i ${local_file.private_key.filename} -o IdentitiesOnly=yes -o ProxyCommand='ssh -i ${local_file.private_key.filename} -o IdentitiesOnly=yes -W %h:%p root@${tolist(linode_instance.nat_gateway.ipv4)[0]}' root@${local.private_vm_ip} 'chmod +x /root/setup_wireguard_client.sh && /root/setup_wireguard_client.sh --config /root/wg0.conf --apt-proxy http://${local.nat_gateway_ip}:8080'
  EOT
}
