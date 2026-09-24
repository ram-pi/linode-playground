locals {
  service_fqdn = "hello.${linode_domain.main.domain}"

  deployments = {
    primary = {
      cluster_label = "lke-ent-nodeport-dns-primary"
      client_label  = "lke-enterprise-nodeport-client"
      subnet_label  = "lke-enterprise-nodeport-subnet"
      ipv4_cidr     = var.vpc_ipv4_cidr
    }
    secondary = {
      cluster_label = "lke-ent-nodeport-dns-secondary"
      client_label  = "lke-enterprise-nodeport-client-secondary"
      subnet_label  = "lke-enterprise-nodeport-subnet-secondary"
      ipv4_cidr     = var.secondary_vpc_ipv4_cidr
    }
  }

  client_public_ipv4 = {
    for name, interface in linode_interface.client :
    name => one(interface.vpc.ipv4.assigned_addresses).nat_1_1_address
  }

  client_vpc_ipv4 = {
    for name, interface in linode_interface.client :
    name => one(interface.vpc.ipv4.assigned_addresses).address
  }
}

resource "tls_private_key" "client" {
  algorithm = "ED25519"
}

moved {
  from = linode_vpc_subnet.main
  to   = linode_vpc_subnet.main["primary"]
}

moved {
  from = linode_lke_cluster.main
  to   = linode_lke_cluster.main["primary"]
}

moved {
  from = linode_instance.client
  to   = linode_instance.client["primary"]
}

moved {
  from = linode_instance_disk.client
  to   = linode_instance_disk.client["primary"]
}

moved {
  from = linode_interface.client
  to   = linode_interface.client["primary"]
}

moved {
  from = linode_instance_config.client
  to   = linode_instance_config.client["primary"]
}
