# Terraform configuration for Linode VPC and Subnet

resource "linode_vpc" "main" {
  label  = "main"
  region = var.vpc_region
}

resource "linode_vpc_subnet" "public" {
  vpc_id = linode_vpc.main.id
  label  = "public"
  ipv4   = "10.10.1.0/24"
}

resource "linode_vpc_subnet" "private" {
  vpc_id = linode_vpc.main.id
  label  = "private"
  ipv4   = "10.10.2.0/24"
}

resource "linode_firewall" "public-firewall" {
  label = "public-firewall"

  inbound {
    label    = "allow-ssh-from-my-ip"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "22"
    ipv4     = [local.my_ip]
  }

  inbound {
    label    = "allow-tcp-vpc"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "1-65535"
    ipv4     = ["10.0.0.0/8"]
  }

  inbound {
    label    = "allow-udp-vpc"
    action   = "ACCEPT"
    protocol = "UDP"
    ports    = "1-65535"
    ipv4     = ["10.0.0.0/8"]
  }

  inbound {
    label    = "allow-icmp-vpc"
    action   = "ACCEPT"
    protocol = "ICMP"
    ipv4     = ["10.0.0.0/8"]
  }

  inbound_policy  = "DROP"
  outbound_policy = "ACCEPT"

  linodes = [
    linode_instance.public.id
  ]
}

resource "linode_firewall" "private-firewall" {
  label = "private-firewall"

  inbound {
    label    = "allow-tcp-vpc"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "1-65535"
    ipv4     = ["10.0.0.0/8"]
  }

  inbound {
    label    = "allow-udp-vpc"
    action   = "ACCEPT"
    protocol = "UDP"
    ports    = "1-65535"
    ipv4     = ["10.0.0.0/8"]
  }

  inbound {
    label    = "allow-icmp-vpc"
    action   = "ACCEPT"
    protocol = "ICMP"
    ipv4     = ["10.0.0.0/8"]
  }

  inbound_policy  = "DROP"
  outbound_policy = "ACCEPT"

  linodes = [
    linode_instance.private.id
  ]
}
