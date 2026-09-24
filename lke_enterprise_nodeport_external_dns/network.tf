resource "linode_vpc" "main" {
  label  = "lke-enterprise-nodeport-vpc"
  region = var.region

  ipv6 = [{
    range = "/48"
  }]
}

resource "linode_vpc_subnet" "main" {
  for_each = local.deployments

  vpc_id = linode_vpc.main.id
  label  = each.value.subnet_label
  ipv4   = each.value.ipv4_cidr

  ipv6 = [{
    range = "/52"
  }]
}

resource "linode_firewall" "client" {
  label = "lke-enterprise-nodeport-client"
  tags  = var.tags

  inbound {
    label    = "allow-ssh"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "22"
    ipv4     = var.ssh_allowed_ipv4_cidrs
  }

  inbound {
    label    = "allow-vpc-icmp"
    action   = "ACCEPT"
    protocol = "ICMP"
    ipv4     = [for deployment in values(local.deployments) : deployment.ipv4_cidr]
  }

  inbound_policy  = "DROP"
  outbound_policy = "ACCEPT"
}

resource "linode_firewall" "lke_pool" {
  label = "lke-enterprise-nodepool"
  tags  = var.tags

  inbound {
    label    = "allow-vpc"
    action   = "ACCEPT"
    protocol = "ALL"
    ipv4     = ["10.0.0.0/8"]
  }

  inbound_policy  = "DROP"
  outbound_policy = "ACCEPT"
}
