resource "linode_firewall" "director" {
  label = "lvs-dr-director-fw-${var.region}"
  tags  = local.tags

  inbound {
    label    = "allow-ssh"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "22"
    ipv4     = local.my_ip_cidrs
  }

  inbound {
    label    = "allow-http-for-testing"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "80,8404,${var.nodeport_http}"
    ipv4     = local.my_ip_cidrs
  }

  inbound_policy  = "DROP"
  outbound_policy = "ACCEPT"

  linodes = [linode_instance.director.id]
}
