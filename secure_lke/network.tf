locals {
  private_ips_range = "192.168.128.0/17"
}

resource "linode_firewall" "allow-my-ip" {
  label = "allow-${local.my_ip_}"

  inbound {
    label    = "allow-tcp-from-${local.my_ip_}"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "1-65535"
    ipv4     = [local.my_ip_cidr]
  }

  inbound {
    label    = "allow-udb-from-${local.my_ip_}"
    action   = "ACCEPT"
    protocol = "UDP"
    ports    = "1-65535"
    ipv4     = [local.my_ip_cidr]
  }

  inbound {
    label    = "allow-icmp-from-${local.my_ip_}"
    action   = "ACCEPT"
    protocol = "ICMP"
    ipv4     = [local.my_ip_cidr]
  }

  inbound {
    label    = "allow-tcp-vpc"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "1-65535"
    ipv4     = [local.private_ips_range]
  }

  inbound {
    label    = "allow-udp-vpc"
    action   = "ACCEPT"
    protocol = "UDP"
    ports    = "1-65535"
    ipv4     = [local.private_ips_range]
  }

  inbound {
    label    = "allow-icmp-vpc"
    action   = "ACCEPT"
    protocol = "ICMP"
    ipv4     = [local.private_ips_range]
  }

  inbound_policy  = "DROP"
  outbound_policy = "ACCEPT"

  tags = ["prametta"]
}
