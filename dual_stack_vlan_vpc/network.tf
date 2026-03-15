resource "linode_vpc" "vpc1" {
  label  = "dual-stack-vpc1"
  region = local.region
}

resource "linode_vpc_subnet" "vpc1" {
  vpc_id = linode_vpc.vpc1.id
  label  = "vpc1-subnet"
  ipv4   = local.vpc1_cidr
}

resource "linode_vpc" "vpc2" {
  label  = "dual-stack-vpc2"
  region = local.region
}

resource "linode_vpc_subnet" "vpc2" {
  vpc_id = linode_vpc.vpc2.id
  label  = "vpc2-subnet"
  ipv4   = local.vpc2_cidr
}

resource "random_string" "firewall_suffix" {
  length  = 4
  special = false
  upper   = false
}

resource "linode_firewall" "allow_my_ip_and_internal" {
  label = "firewall-${random_string.firewall_suffix.result}"

  inbound {
    label    = "allow-tcp-${random_string.firewall_suffix.result}"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "1-65535"
    ipv4 = concat(
      [
        local.my_ip_cidr,
        local.private_ip_cidr,
        local.vlan_cidr,
        linode_vpc_subnet.vpc1.ipv4,
        linode_vpc_subnet.vpc2.ipv4,
      ],
      var.ipv4_whitelist_cidrs
    )
  }

  inbound {
    label    = "allow-udp-${random_string.firewall_suffix.result}"
    action   = "ACCEPT"
    protocol = "UDP"
    ports    = "1-65535"
    ipv4 = concat(
      [
        local.my_ip_cidr,
        local.private_ip_cidr,
        local.vlan_cidr,
        linode_vpc_subnet.vpc1.ipv4,
        linode_vpc_subnet.vpc2.ipv4,
      ],
      var.ipv4_whitelist_cidrs
    )
  }

  inbound {
    label    = "allow-icmp-${random_string.firewall_suffix.result}"
    action   = "ACCEPT"
    protocol = "ICMP"
    ipv4 = concat(
      [
        local.my_ip_cidr,
        local.private_ip_cidr,
        local.vlan_cidr,
        linode_vpc_subnet.vpc1.ipv4,
        linode_vpc_subnet.vpc2.ipv4,
      ],
      var.ipv4_whitelist_cidrs
    )
  }

  inbound_policy  = "DROP"
  outbound_policy = "ACCEPT"

  tags = local.tags
}
