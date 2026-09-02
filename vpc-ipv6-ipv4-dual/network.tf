resource "linode_vpc" "main" {
  label       = "${var.label_prefix}-${random_string.suffix.result}"
  region      = var.region
  description = "Dual-stack (IPv4 + IPv6) VPC demo"

  ipv6 = [
    {
      range = var.vpc_ipv6_prefix
    }
  ]
}

resource "linode_vpc_subnet" "main" {
  vpc_id = linode_vpc.main.id
  label  = "${var.label_prefix}-subnet"
  ipv4   = var.subnet_ipv4_cidr

  ipv6 = [
    {
      range = var.subnet_ipv6_range
    }
  ]
}

resource "linode_firewall" "main" {
  label = "fw-${var.label_prefix}-${random_string.suffix.result}"

  inbound {
    label    = "ssh"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "22"
    ipv4     = concat([local.my_ip_cidr], var.ssh_allowed_ipv4_cidrs)
  }

  inbound {
    label    = "vpc-tcp"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "1-65535"
    ipv4     = [var.subnet_ipv4_cidr]
    ipv6     = [linode_vpc_subnet.main.ipv6[0].allocated_range]
  }

  inbound {
    label    = "vpc-udp"
    action   = "ACCEPT"
    protocol = "UDP"
    ports    = "1-65535"
    ipv4     = [var.subnet_ipv4_cidr]
    ipv6     = [linode_vpc_subnet.main.ipv6[0].allocated_range]
  }

  inbound {
    label    = "vpc-icmp"
    action   = "ACCEPT"
    protocol = "ICMP"
    ipv4     = [var.subnet_ipv4_cidr]
    ipv6     = [linode_vpc_subnet.main.ipv6[0].allocated_range]
  }

  inbound_policy  = "DROP"
  outbound_policy = "ACCEPT"

  tags = var.tags
}
