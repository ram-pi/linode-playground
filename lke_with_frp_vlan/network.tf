resource "linode_firewall" "frp_server" {
  label = "frp-server-fw-${var.region}"
  tags  = local.tags

  # This firewall applies to the VM public interface.
  # VLAN traffic is handled by VLAN addressing/routing, not by this firewall path.

  inbound {
    label    = "allow-ssh"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "22"
    ipv4     = var.ipv4_whitelist_cidrs
  }

  inbound {
    label    = "allow-frp-bind"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = tostring(var.frp_bind_port)
    ipv4     = concat([var.vlan_cidr], var.ipv4_whitelist_cidrs)
  }

  inbound {
    label    = "allow-frp-remote"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = tostring(var.frp_remote_port)
    ipv4     = concat([var.vlan_cidr], var.ipv4_whitelist_cidrs)
  }

  inbound {
    label    = "allow-frp-admin"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "7500"
    ipv4     = concat([var.vlan_cidr], var.ipv4_whitelist_cidrs)
  }

  inbound_policy  = "DROP"
  outbound_policy = "ACCEPT"
}
