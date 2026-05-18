resource "linode_vpc" "main" {
  label  = "${var.project_name}-vpc"
  region = local.region
}

resource "linode_vpc_subnet" "observability" {
  vpc_id = linode_vpc.main.id
  label  = "${var.project_name}-subnet"
  ipv4   = var.vpc_cidr
}

resource "linode_firewall" "observability" {
  label = "${var.project_name}-fw"

  inbound {
    label    = "allow-ssh-my-ip"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "22"
    ipv4     = [local.my_ip_cidr]
  }

  inbound {
    label    = "allow-ui-my-ip"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "3000,9090"
    ipv4     = [local.my_ip_cidr]
  }

  inbound {
    label    = "allow-vpc-tcp"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "1-65535"
    ipv4     = [var.vpc_cidr]
  }

  inbound {
    label    = "allow-vpc-udp"
    action   = "ACCEPT"
    protocol = "UDP"
    ports    = "1-65535"
    ipv4     = [var.vpc_cidr]
  }

  inbound {
    label    = "allow-vpc-icmp"
    action   = "ACCEPT"
    protocol = "ICMP"
    ipv4     = [var.vpc_cidr]
  }

  inbound_policy  = "DROP"
  outbound_policy = "ACCEPT"
}
