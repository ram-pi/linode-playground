resource "linode_firewall" "proxy" {
  label = "proxy-fw-${var.region}"
  tags  = local.tags

  inbound {
    label    = "allow-ssh"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "22"
    ipv4     = local.my_ip_cidr
  }

  inbound {
    label    = "allow-http"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "80,443,8404"
    ipv4     = concat(local.my_ip_cidr, [for ip in linode_instance.client.ipv4 : "${ip}/32"])
  }

  inbound_policy  = "DROP"
  outbound_policy = "ACCEPT"

  linodes = [linode_instance.proxy.id]
}

resource "linode_firewall" "client" {
  label = "client-fw-${var.region}"
  tags  = local.tags

  inbound {
    label    = "allow-ssh"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "22"
    ipv4     = local.my_ip_cidr
  }

  inbound_policy  = "DROP"
  outbound_policy = "ACCEPT"

  linodes = [linode_instance.client.id]
}
