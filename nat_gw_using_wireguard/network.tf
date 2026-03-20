resource "random_string" "firewall_suffix" {
  length  = 4
  special = false
  upper   = false
}

resource "linode_vpc" "main" {
  label  = "nat-gw-wg-vpc"
  region = local.region
}

resource "linode_vpc_subnet" "main" {
  vpc_id = linode_vpc.main.id
  label  = "nat-gw-wg-subnet"
  ipv4   = local.vpc_cidr
}

resource "linode_firewall" "nat_gateway" {
  label = "nat-gw-wg-fw-${random_string.firewall_suffix.result}"

  inbound {
    label    = "ssh-admin"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "22"
    ipv4     = concat([local.my_ip_cidr], var.ipv4_whitelist_cidrs)
  }

  inbound {
    label    = "wireguard"
    action   = "ACCEPT"
    protocol = "UDP"
    ports    = "51820"
    ipv4     = [linode_vpc_subnet.main.ipv4]
  }

  inbound {
    label    = "internal-tcp"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "1-65535"
    ipv4     = [linode_vpc_subnet.main.ipv4]
  }

  inbound {
    label    = "internal-udp"
    action   = "ACCEPT"
    protocol = "UDP"
    ports    = "1-65535"
    ipv4     = [linode_vpc_subnet.main.ipv4]
  }

  inbound {
    label    = "internal-icmp"
    action   = "ACCEPT"
    protocol = "ICMP"
    ipv4     = [linode_vpc_subnet.main.ipv4]
  }

  inbound_policy  = "DROP"
  outbound_policy = "ACCEPT"

  tags = local.tags
}

resource "linode_firewall" "private_vm" {
  label = "private-vm-fw-${random_string.firewall_suffix.result}"

  inbound {
    label    = "internal-tcp"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "1-65535"
    ipv4     = [linode_vpc_subnet.main.ipv4]
  }

  inbound {
    label    = "internal-udp"
    action   = "ACCEPT"
    protocol = "UDP"
    ports    = "1-65535"
    ipv4     = [linode_vpc_subnet.main.ipv4]
  }

  inbound {
    label    = "internal-icmp"
    action   = "ACCEPT"
    protocol = "ICMP"
    ipv4     = [linode_vpc_subnet.main.ipv4]
  }

  inbound_policy  = "DROP"
  outbound_policy = "ACCEPT"

  tags = local.tags
}
