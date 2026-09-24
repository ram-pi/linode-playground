# The VPC and subnet must be dual-stack for a custom VPC to be assigned to an
# LKE Enterprise cluster, so both allocate an IPv6 prefix in addition to IPv4.
resource "linode_vpc" "main" {
  label  = "${var.cluster_label}-vpc"
  region = var.region

  ipv6 = [{
    range = var.vpc_ipv6_prefix
  }]
}

resource "linode_vpc_subnet" "main" {
  vpc_id = linode_vpc.main.id
  label  = "${var.cluster_label}-subnet"
  ipv4   = var.vpc_ipv4_cidr

  ipv6 = [{
    range = var.subnet_ipv6_prefix
  }]
}

resource "linode_firewall" "kafka_pool" {
  label = "${var.cluster_label}-nodepool"
  tags  = var.tags

  # All intra-VPC traffic: broker<->controller, broker<->broker replication, and
  # the internal listener used by in-cluster clients.
  inbound {
    label    = "allow-vpc"
    action   = "ACCEPT"
    protocol = "ALL"
    ipv4     = [var.vpc_ipv4_cidr]
    ipv6     = [linode_vpc_subnet.main.ipv6[0].allocated_range]
  }

  # NodePort listener range. Defaults to the VPC CIDR so the external listener is
  # reachable only from inside the VPC (advertised address is the node InternalIP).
  # Using a contiguous range also covers any NodePort that Strimzi may reassign.
  inbound {
    label    = "allow-kafka-nodeport"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = local.nodeport_range
    ipv4     = var.broker_nodeport_allowed_ipv4_cidrs
    ipv6     = [linode_vpc_subnet.main.ipv6[0].allocated_range]
  }

  inbound_policy  = "DROP"
  outbound_policy = "ACCEPT"
}
