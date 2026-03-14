resource "linode_vpc" "main" {
  label  = "active-passive-vpc"
  region = local.region
}

resource "linode_vpc_subnet" "main" {
  vpc_id = linode_vpc.main.id
  label  = "active-passive-subnet"
  ipv4   = local.vpc_cidr
}

resource "linode_firewall" "allow_my_ip_and_internal" {
  label = "allow-my-ip-and-internal"

  inbound {
    label    = "allow-tcp-from-${local.my_ip_}"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "1-65535"
    ipv4 = concat(
      [
        local.my_ip_cidr,
        local.private_ip_cidr,
        local.vlan_cidr,
        linode_vpc_subnet.main.ipv4,
      ],
      var.ipv4_whitelist_cidrs
    )
  }

  inbound {
    label    = "allow-udp-from-${local.my_ip_}"
    action   = "ACCEPT"
    protocol = "UDP"
    ports    = "1-65535"
    ipv4 = concat(
      [
        local.my_ip_cidr,
        local.private_ip_cidr,
        local.vlan_cidr,
        linode_vpc_subnet.main.ipv4,
      ],
      var.ipv4_whitelist_cidrs
    )
  }

  inbound {
    label    = "allow-icmp-from-${local.my_ip_}"
    action   = "ACCEPT"
    protocol = "ICMP"
    ipv4 = concat(
      [
        local.my_ip_cidr,
        local.private_ip_cidr,
        local.vlan_cidr,
        linode_vpc_subnet.main.ipv4,
      ],
      var.ipv4_whitelist_cidrs
    )
  }

  inbound_policy  = "DROP"
  outbound_policy = "ACCEPT"

  tags = local.tags
}
