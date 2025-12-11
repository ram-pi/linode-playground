resource "linode_vpc" "main" {
  label  = "main"
  region = local.region
}

resource "linode_vpc_subnet" "subnet-1" {
  vpc_id = linode_vpc.main.id
  label  = "subnet-1"
  ipv4   = "10.10.1.0/24"
}

resource "linode_vpc_subnet" "subnet-2" {
  vpc_id = linode_vpc.main.id
  label  = "subnet-2"
  ipv4   = "10.10.2.0/24"
}

resource "linode_firewall" "allow-my-ip-and-internal" {
  label = "allow-${local.my_ip_}"

  inbound {
    label    = "allow-tcp-from-${local.my_ip_}"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "1-65535"
    ipv4     = [local.my_ip_cidr]
  }

  inbound {
    label    = "allow-udb-from-${local.my_ip_}"
    action   = "ACCEPT"
    protocol = "UDP"
    ports    = "1-65535"
    ipv4     = [local.my_ip_cidr]
  }

  inbound {
    label    = "allow-icmp-from-${local.my_ip_}"
    action   = "ACCEPT"
    protocol = "ICMP"
    ipv4     = [local.my_ip_cidr]
  }

  inbound {
    label    = "allow-tcp-internal"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "1-65535"
    ipv4 = [
      linode_vpc_subnet.subnet-1.ipv4,
      linode_vpc_subnet.subnet-2.ipv4
    ]
  }

  inbound {
    label    = "allow-udp-internal"
    action   = "ACCEPT"
    protocol = "UDP"
    ports    = "1-65535"
    ipv4 = [
      linode_vpc_subnet.subnet-1.ipv4,
      linode_vpc_subnet.subnet-2.ipv4
    ]
  }

  inbound {
    label    = "allow-icmp-internal"
    action   = "ACCEPT"
    protocol = "ICMP"
    ipv4 = [
      linode_vpc_subnet.subnet-1.ipv4,
      linode_vpc_subnet.subnet-2.ipv4
    ]
  }

  inbound_policy  = "DROP"
  outbound_policy = "ACCEPT"

  tags = ["prametta"]
}
