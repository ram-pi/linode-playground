resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  content         = tls_private_key.ssh_key.private_key_openssh
  filename        = "${local.temp_path}/id_rsa"
  file_permission = "0600"
}

resource "local_file" "public_key" {
  content         = tls_private_key.ssh_key.public_key_openssh
  filename        = "${local.temp_path}/id_rsa.pub"
  file_permission = "0644"
}

resource "random_password" "root_password" {
  length  = 16
  special = true
}

resource "random_password" "keepalived_auth_pass" {
  length  = 8
  special = false
}

resource "linode_instance" "host_01" {
  label       = "ap-vip-host-01"
  region      = local.region
  type        = local.instance_type
  image       = local.image
  tags        = local.tags
  firewall_id = linode_firewall.allow_my_ip_and_internal.id
  authorized_keys = [
    chomp(tls_private_key.ssh_key.public_key_openssh)
  ]
  root_pass = random_password.root_password.result

  interface {
    purpose   = "vpc"
    subnet_id = linode_vpc_subnet.main.id
    ipv4 {
      nat_1_1 = "any"
      vpc     = local.vpc_address_map["host_01"]
    }
  }

  interface {
    purpose      = "vlan"
    label        = "vlan0"
    ipam_address = local.vlan_address_map["host_01"]
  }

  swap_size = 256
}

resource "linode_instance" "host_02" {
  label       = "ap-vip-host-02"
  region      = local.region
  type        = local.instance_type
  image       = local.image
  tags        = local.tags
  firewall_id = linode_firewall.allow_my_ip_and_internal.id
  authorized_keys = [
    chomp(tls_private_key.ssh_key.public_key_openssh)
  ]
  root_pass = random_password.root_password.result

  interface {
    purpose   = "vpc"
    subnet_id = linode_vpc_subnet.main.id
    ipv4 {
      nat_1_1 = "any"
      vpc     = local.vpc_address_map["host_02"]
    }
  }

  interface {
    purpose      = "vlan"
    label        = "vlan0"
    ipam_address = local.vlan_address_map["host_02"]
  }

  swap_size = 256
}

resource "linode_instance" "host_03" {
  label       = "ap-vip-host-03"
  region      = local.region
  type        = local.instance_type
  image       = local.image
  tags        = local.tags
  firewall_id = linode_firewall.allow_my_ip_and_internal.id
  authorized_keys = [
    chomp(tls_private_key.ssh_key.public_key_openssh)
  ]
  root_pass = random_password.root_password.result

  interface {
    purpose   = "vpc"
    subnet_id = linode_vpc_subnet.main.id
    ipv4 {
      nat_1_1 = "any"
      vpc     = local.vpc_address_map["host_03"]
    }
  }

  interface {
    purpose      = "vlan"
    label        = "vlan0"
    ipam_address = local.vlan_address_map["host_03"]
  }

  swap_size = 256
}
