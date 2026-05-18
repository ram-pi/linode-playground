resource "linode_vpc" "main" {
  label  = var.vpc_label
  region = var.region
}

resource "linode_vpc_subnet" "main" {
  vpc_id = linode_vpc.main.id
  label  = "${var.vpc_label}-subnet"
  ipv4   = var.subnet_cidr
}

resource "linode_firewall" "vm" {
  label = "linode-moe-fw-${local.caller_label}"
  tags  = var.tags

  # SSH only from current operator IP.
  inbound {
    label    = "allow-ssh-from-operator"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "22"
    ipv4     = [local.caller_cidr]
  }

  # Allow private traffic in VPC (for future extensions).
  inbound {
    label    = "allow-vpc-tcp"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "1-65535"
    ipv4     = [linode_vpc_subnet.main.ipv4]
  }

  inbound {
    label    = "allow-vpc-udp"
    action   = "ACCEPT"
    protocol = "UDP"
    ports    = "1-65535"
    ipv4     = [linode_vpc_subnet.main.ipv4]
  }

  inbound {
    label    = "allow-vpc-icmp"
    action   = "ACCEPT"
    protocol = "ICMP"
    ipv4     = [linode_vpc_subnet.main.ipv4]
  }

  inbound_policy  = "DROP"
  outbound_policy = "ACCEPT"
}
