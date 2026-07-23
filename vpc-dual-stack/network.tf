resource "linode_vpc" "main" {
  label  = "vpc-dual-stack-${random_string.suffix.result}"
  region = var.region

  ipv6 = [
    {
      range = var.vpc_ipv6_prefix
    }
  ]
}

resource "linode_vpc_subnet" "main" {
  vpc_id = linode_vpc.main.id
  label  = "vpc-dual-stack-subnet"
  ipv4   = var.vpc_ipv4_cidr

  ipv6 = [
    {
      range = "auto"
    }
  ]
}

resource "linode_firewall" "main" {
  label = "fw-vpc-dual-stack-${random_string.suffix.result}"

  inbound {
    label    = "ssh"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "22"
    ipv4     = concat([local.my_ip_cidr], var.ssh_allowed_ipv4_cidrs)
  }

  inbound {
    label    = "allow-vpc-tcp"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "1-65535"
    ipv4     = [var.vpc_ipv4_cidr]
    ipv6     = [linode_vpc_subnet.main.ipv6[0].allocated_range]
  }

  inbound {
    label    = "allow-vpc-udp"
    action   = "ACCEPT"
    protocol = "UDP"
    ports    = "1-65535"
    ipv4     = [var.vpc_ipv4_cidr]
    ipv6     = [linode_vpc_subnet.main.ipv6[0].allocated_range]
  }

  inbound {
    label    = "allow-vpc-icmp"
    action   = "ACCEPT"
    protocol = "ICMP"
    ipv4     = [var.vpc_ipv4_cidr]
    ipv6     = [linode_vpc_subnet.main.ipv6[0].allocated_range]
  }

  inbound_policy  = "DROP"
  outbound_policy = "ACCEPT"

  tags = var.tags
}
