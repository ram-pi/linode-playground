# Terraform configuration for Linode VPC and Subnet

resource "linode_vpc" "main" {
  label  = "main"
  region = local.region
}

resource "linode_firewall" "allow-my-ip" {
  label = "allow-${local.my_ip_}"

  inbound {
    label    = "allow-tcp-from-${local.my_ip_}"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "1-65535"
    ipv4     = [local.my_ip]
  }

  inbound {
    label    = "allow-udb-from-${local.my_ip_}"
    action   = "ACCEPT"
    protocol = "UDP"
    ports    = "1-65535"
    ipv4     = [local.my_ip]
  }

  inbound {
    label    = "allow-icmp-from-${local.my_ip_}"
    action   = "ACCEPT"
    protocol = "ICMP"
    ipv4     = [local.my_ip]
  }

  inbound {
    label    = "allow-tcp-vpc"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "1-65535"
    ipv4     = ["10.0.0.0/8"]
  }

  inbound {
    label    = "allow-udp-vpc"
    action   = "ACCEPT"
    protocol = "UDP"
    ports    = "1-65535"
    ipv4     = ["10.0.0.0/8"]
  }

  inbound {
    label    = "allow-icmp-vpc"
    action   = "ACCEPT"
    protocol = "ICMP"
    ipv4     = ["10.0.0.0/8"]
  }

  inbound_policy  = "DROP"
  outbound_policy = "ACCEPT"

  tags = ["prametta"]
}
