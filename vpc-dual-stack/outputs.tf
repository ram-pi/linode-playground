output "ssh_private_key_path" {
  description = "Path to generated SSH private key"
  value       = local_file.private_key.filename
}

output "vm1_public_ipv4" {
  description = "Public IPv4 of vm1"
  value       = tolist(linode_instance.vm1.ipv4)[0]
}

output "vm2_public_ipv4" {
  description = "Public IPv4 of vm2"
  value       = tolist(linode_instance.vm2.ipv4)[0]
}

output "vm3_public_ipv4" {
  description = "Public IPv4 of vm3"
  value       = tolist(linode_instance.vm3.ipv4)[0]
}

output "vm1_vpc_ipv4" {
  description = "Static VPC IPv4 of vm1"
  value       = local.vm1_vpc_ipv4
}

output "vm2_vpc_ipv4" {
  description = "Static VPC IPv4 of vm2"
  value       = local.vm2_vpc_ipv4
}

output "vm3_vpc_ipv4" {
  description = "Static VPC IPv4 of vm3"
  value       = local.vm3_vpc_ipv4
}

output "vm1_vlan_ip" {
  description = "VLAN IP of vm1"
  value       = local.vm1_vlan_ipam
}

output "vm2_vlan_ip" {
  description = "VLAN IP of vm2"
  value       = local.vm2_vlan_ipam
}

output "vm3_vlan_ip" {
  description = "VLAN IP of vm3"
  value       = local.vm3_vlan_ipam
}

output "vpc_ipv6_allocated_range" {
  description = "Allocated IPv6 range for the VPC"
  value       = linode_vpc.main.ipv6[0].allocated_range
}

output "vpc_subnet_ipv6_allocated_range" {
  description = "Allocated IPv6 range for the VPC subnet"
  value       = linode_vpc_subnet.main.ipv6[0].allocated_range
}

output "ssh_command_vm1" {
  description = "SSH command for vm1"
  value       = "ssh -i ${local_file.private_key.filename} root@${tolist(linode_instance.vm1.ipv4)[0]}"
}

output "ssh_command_vm2" {
  description = "SSH command for vm2"
  value       = "ssh -i ${local_file.private_key.filename} root@${tolist(linode_instance.vm2.ipv4)[0]}"
}

output "ssh_command_vm3" {
  description = "SSH command for vm3"
  value       = "ssh -i ${local_file.private_key.filename} root@${tolist(linode_instance.vm3.ipv4)[0]}"
}
