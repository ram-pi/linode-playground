### Linode Firewall to allow all internal traffic ###
resource "linode_firewall" "allow-my-ip-and-internal" {
  label = "allow-${local.my_ip_}"

  inbound {
    label    = "allow-tcp-from-${local.my_ip_}"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "1-65535"
    ipv4 = concat(
      [
        local.my_ip_cidr,
        local.private_ip_cidr,
      ],
      var.ipv4_whitelist_cidrs
    )
  }

  inbound {
    label    = "allow-udb-from-${local.my_ip_}"
    action   = "ACCEPT"
    protocol = "UDP"
    ports    = "1-65535"
    ipv4 = concat(
      [
        local.my_ip_cidr,
        local.private_ip_cidr,
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
      ],
      var.ipv4_whitelist_cidrs
    )
  }

  inbound_policy  = "DROP"
  outbound_policy = "ACCEPT"

  tags = ["prametta"]
}
