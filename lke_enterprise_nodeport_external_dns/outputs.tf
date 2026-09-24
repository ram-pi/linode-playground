output "cluster_id" {
  description = "Primary LKE Enterprise cluster ID"
  value       = linode_lke_cluster.main["primary"].id
}

output "secondary_cluster_id" {
  description = "Secondary LKE Enterprise cluster ID"
  value       = linode_lke_cluster.main["secondary"].id
}

output "k8s_version" {
  description = "Kubernetes version deployed to the cluster"
  value       = linode_lke_cluster.main["primary"].k8s_version
}

output "vpc_id" {
  description = "Shared VPC ID"
  value       = linode_vpc.main.id
}

output "vpc_ipv4_cidr" {
  description = "Primary VPC subnet IPv4 CIDR"
  value       = linode_vpc_subnet.main["primary"].ipv4
}

output "secondary_vpc_ipv4_cidr" {
  description = "Secondary VPC subnet IPv4 CIDR"
  value       = linode_vpc_subnet.main["secondary"].ipv4
}

output "subnet_id" {
  description = "Primary dual-stack VPC subnet ID"
  value       = linode_vpc_subnet.main["primary"].id
}

output "secondary_subnet_id" {
  description = "Secondary dual-stack VPC subnet ID"
  value       = linode_vpc_subnet.main["secondary"].id
}

output "client_public_ipv4" {
  description = "Client 1:1 NAT public IPv4 address"
  value       = local.client_public_ipv4["primary"]
}

output "secondary_client_public_ipv4" {
  description = "Secondary client 1:1 NAT public IPv4 address"
  value       = local.client_public_ipv4["secondary"]
}

output "client_ssh_command" {
  description = "Command to SSH into the primary client"
  value       = "ssh -i client_key root@${local.client_public_ipv4["primary"]}"
}

output "secondary_client_ssh_command" {
  description = "Command to SSH into the secondary client"
  value       = "ssh -i client_key root@${local.client_public_ipv4["secondary"]}"
}

output "client_vpc_ipv4" {
  description = "Primary client DHCP-assigned VPC IPv4 address"
  value       = local.client_vpc_ipv4["primary"]
}

output "secondary_client_vpc_ipv4" {
  description = "Secondary client DHCP-assigned VPC IPv4 address"
  value       = local.client_vpc_ipv4["secondary"]
}

output "client_private_key" {
  description = "Generated SSH private key for the client"
  value       = tls_private_key.client.private_key_openssh
  sensitive   = true
}

output "service_fqdn" {
  description = "FQDN managed by ExternalDNS"
  value       = local.service_fqdn
}

output "dns_zone" {
  description = "Linode DNS zone created for the demo"
  value       = linode_domain.main.domain
}

output "domain_id" {
  description = "Linode DNS zone ID"
  value       = linode_domain.main.id
}

output "node_port" {
  description = "Hello service NodePort"
  value       = var.node_port
}

output "linode_nameservers" {
  description = "Authoritative Linode nameservers used for the .internal zone"
  value       = var.linode_nameservers
}
