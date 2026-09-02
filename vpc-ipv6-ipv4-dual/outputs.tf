output "vpc_id" {
  description = "ID of the dual-stack VPC"
  value       = linode_vpc.main.id
}

output "vpc_label" {
  description = "Label of the dual-stack VPC"
  value       = linode_vpc.main.label
}

output "vpc_ipv6_range" {
  description = "IPv6 range allocated to the VPC by Linode"
  value       = try(linode_vpc.main.ipv6[0].allocated_range, null)
}

output "subnet_id" {
  description = "ID of the VPC subnet"
  value       = linode_vpc_subnet.main.id
}

output "subnet_ipv4_cidr" {
  description = "IPv4 CIDR of the VPC subnet"
  value       = linode_vpc_subnet.main.ipv4
}

output "subnet_ipv6_range" {
  description = "IPv6 range allocated to the VPC subnet by Linode"
  value       = try(linode_vpc_subnet.main.ipv6[0].allocated_range, null)
}

output "vm_ids" {
  description = "IDs of the demo VMs"
  value       = { for name, vm in linode_instance.vm : name => vm.id }
}

output "vm_vpc_ipv4" {
  description = "VPC IPv4 address of each VM"
  value       = local.vm_vpc_ipv4
}

output "vm_public_ipv4" {
  description = "Public IPv4 address 1:1 NAT'd to each VM's VPC address"
  value = {
    for name, iface in linode_interface.vpc :
    name => try(tolist(iface.vpc.ipv4.assigned_addresses)[0].nat_1_1_address, null)
  }
}

output "vm_vpc_ipv6_slaac_range" {
  description = "SLAAC IPv6 range assigned to each VM's VPC interface"
  value = {
    for name, iface in linode_interface.vpc :
    name => try(tolist(iface.vpc.ipv6.assigned_slaac)[0].range, null)
  }
}

output "ssh_private_key_path" {
  description = "Path to the generated SSH private key"
  value       = local_file.private_key.filename
}

output "ssh_commands" {
  description = "SSH command for each VM"
  value = {
    for name, iface in linode_interface.vpc :
    name => "ssh -i ${local_file.private_key.filename} root@${try(tolist(iface.vpc.ipv4.assigned_addresses)[0].nat_1_1_address, "")}"
  }
}
