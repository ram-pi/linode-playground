locals {
  host_1_public_ip = tolist(linode_instance.host_1.ipv4[*])[0]
  host_2_public_ip = tolist(linode_instance.host_2.ipv4[*])[0]
  host_3_public_ip = tolist(linode_instance.host_3.ipv4[*])[0]

  host_1_vlan_ip = split("/", local.vlan_address_map["host_1"])[0]
  host_2_vlan_ip = split("/", local.vlan_address_map["host_2"])[0]

  host_1_vpc_ip = local.vpc1_address_map["host_1"]
  host_2_vpc_ip = local.vpc2_address_map["host_2"]
  host_3_vpc_ip = local.vpc2_address_map["host_3"]
}

output "ssh_command" {
  value       = <<-EOF
    ssh -i ${local_file.private_key.filename} root@${local.host_1_public_ip}
    ssh -i ${local_file.private_key.filename} root@${local.host_2_public_ip}
    ssh -i ${local_file.private_key.filename} root@${local.host_3_public_ip}
    ssh -t ${data.linode_profile.me.username}@lish-${local.region}.linode.com ${linode_instance.host_1.label}
    ssh -t ${data.linode_profile.me.username}@lish-${local.region}.linode.com ${linode_instance.host_2.label}
    ssh -t ${data.linode_profile.me.username}@lish-${local.region}.linode.com ${linode_instance.host_3.label}
  EOF
  description = "SSH and Lish connection commands"
}

output "ssh_root_password" {
  value       = "Root Password: ${random_password.root_password.result}"
  description = "Root password for all hosts"
  sensitive   = true
}

output "host_1_public_ip" {
  value       = local.host_1_public_ip
  description = "Public IPv4 of host-1"
}

output "host_2_public_ip" {
  value       = local.host_2_public_ip
  description = "Public IPv4 of host-2"
}

output "host_3_public_ip" {
  value       = local.host_3_public_ip
  description = "Public IPv4 of host-3"
}

output "topology_summary" {
  value       = <<-EOF
    VLAN vlan1: ${local.vlan_cidr}
      host-1 vlan: ${local.host_1_vlan_ip}
      host-2 vlan: ${local.host_2_vlan_ip}

    VPC vpc1: ${local.vpc1_cidr}
      host-1 vpc: ${local.host_1_vpc_ip}

    VPC vpc2: ${local.vpc2_cidr}
      host-2 vpc: ${local.host_2_vpc_ip}
      host-3 vpc: ${local.host_3_vpc_ip}
  EOF
  description = "Requested dual-stack topology mapping"
}

output "nat_gateway_commands" {
  value       = <<-EOF
    # 1) Configure host-2 as NAT gateway for both subnets
    ssh -i ${local_file.private_key.filename} root@${local.host_2_public_ip} '
      set -e
      dpkg -s iptables-persistent >/dev/null 2>&1 || { apt-get update >/dev/null; DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent >/dev/null; }
      sysctl -w net.ipv4.ip_forward=1
      sed -i "s/^#\?net.ipv4.ip_forward.*/net.ipv4.ip_forward=1/" /etc/sysctl.conf
      grep -q "^net.ipv4.ip_forward=1" /etc/sysctl.conf || echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
      VLAN_IF=$(ip -o -4 addr show | awk "\$4 ~ /^${local.host_2_vlan_ip}\\// {print \$2}")
      VPC_IF=$(ip -o -4 addr show | awk "\$4 ~ /^${local.host_2_vpc_ip}\\// {print \$2}")
      iptables -F FORWARD
      iptables -t nat -F
      iptables -t nat -A POSTROUTING -s ${local.vlan_cidr} -o "$VPC_IF" -j MASQUERADE
      iptables -A FORWARD -i "$VLAN_IF" -o "$VPC_IF" -j ACCEPT
      iptables -A FORWARD -i "$VPC_IF" -o "$VLAN_IF" -j ACCEPT
      ip route replace ${local.host_1_vpc_ip}/32 via ${local.host_1_vlan_ip} dev "$VLAN_IF"
      iptables-save > /etc/iptables/rules.v4
      iptables -t nat -L -n -v
      ip route
    '

    # 2) Route host-1 traffic for host-3 through host-2 VLAN IP
    ssh -i ${local_file.private_key.filename} root@${local.host_1_public_ip} '
      set -e
      VLAN_IF=$(ip -o -4 addr show | awk "\$4 ~ /^${local.host_1_vlan_ip}\\// {print \$2}")
      ip route replace ${local.host_3_vpc_ip}/32 via ${local.host_2_vlan_ip} dev "$VLAN_IF"
      ip route show ${local.host_3_vpc_ip}
    '

    # 3) Return traffic path on host-3 for host-1 via host-2 (bidirectional)
    ssh -i ${local_file.private_key.filename} root@${local.host_3_public_ip} '
      set -e
      VPC_IF=$(ip -o -4 addr show | awk "\$4 ~ /^${local.host_3_vpc_ip}\\// {print \$2}")
      ip route replace ${local.host_1_vpc_ip}/32 via ${local.host_2_vpc_ip} dev "$VPC_IF"
      ip route show ${local.host_1_vpc_ip}
    '

    # 4) Validate connectivity from both sides
    ssh -i ${local_file.private_key.filename} root@${local.host_1_public_ip} 'ping -c 4 ${local.host_3_vpc_ip}'
    ssh -i ${local_file.private_key.filename} root@${local.host_3_public_ip} 'ping -c 4 ${local.host_1_vpc_ip}'

    # 5) Optional packet tracing on host-2 while testing
    ssh -i ${local_file.private_key.filename} root@${local.host_2_public_ip} 'timeout 15 tcpdump -ni any host ${local.host_1_vpc_ip} or host ${local.host_3_vpc_ip}'
  EOF
  description = "Commands to enable and validate host-1 <-> host-3 communication via VLAN-backed NAT gateway"
}
