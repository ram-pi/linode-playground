resource "linode_firewall" "allow-my-ip-and-internal-and-gateways" {
  label = "allow-myip-internal-gateways"

  inbound {
    label    = "allow-tcp"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "1-65535"
    ipv4 = [
      local.my_ip_cidr,                                          # Allow my IP
      local.site_1_site_2_cidr,                                  # Allow Site-1 and Site-2 SUPERSET
      "${tolist(linode_instance.gateway-site-1.ipv4[*])[0]}/32", # Allow gateway site 1 public IP
      "${tolist(linode_instance.gateway-site-2.ipv4[*])[0]}/32"  # Allow gateway site 2 public IP
    ]
  }

  inbound {
    label    = "allow-udp"
    action   = "ACCEPT"
    protocol = "UDP"
    ports    = "1-65535"
    ipv4 = [
      local.my_ip_cidr,                                          # Allow my IP
      local.site_1_site_2_cidr,                                  # Allow Site-1 and Site-2 SUPERSET
      "${tolist(linode_instance.gateway-site-1.ipv4[*])[0]}/32", # Allow gateway site 1 public IP
      "${tolist(linode_instance.gateway-site-2.ipv4[*])[0]}/32"  # Allow gateway site 2 public IP
    ]
  }

  inbound {
    label    = "allow-icmp"
    action   = "ACCEPT"
    protocol = "ICMP"
    ipv4 = [
      local.my_ip_cidr,                                          # Allow my IP
      local.site_1_site_2_cidr,                                  # Allow Site-1 and Site-2 SUPERSET
      "${tolist(linode_instance.gateway-site-1.ipv4[*])[0]}/32", # Allow gateway site 1 public IP
      "${tolist(linode_instance.gateway-site-2.ipv4[*])[0]}/32"  # Allow gateway site 2 public IP
    ]
  }

  inbound_policy  = "DROP"
  outbound_policy = "ACCEPT"

  linodes = [
    linode_instance.gateway-site-1.id,
    linode_instance.gateway-site-2.id
  ]

  tags = ["prametta"]
}

resource "linode_firewall" "allow-my-internal-only" {
  label = "allow-internal-only"

  inbound {
    label    = "allow-tcp-internal"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "1-65535"
    ipv4 = [
      local.site_1_site_2_cidr
    ]
  }

  inbound {
    label    = "allow-udp-internal"
    action   = "ACCEPT"
    protocol = "UDP"
    ports    = "1-65535"
    ipv4 = [
      local.site_1_site_2_cidr
    ]
  }

  inbound {
    label    = "allow-icmp-internal"
    action   = "ACCEPT"
    protocol = "ICMP"
    ipv4 = [
      local.site_1_site_2_cidr
    ]
  }

  inbound_policy  = "DROP"
  outbound_policy = "ACCEPT"

  linodes = [
    linode_instance.host-site-1.id,
    linode_instance.host-site-2.id
  ]

  tags = ["prametta"]
}
