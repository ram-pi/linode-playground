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

resource "linode_instance" "host_1" {
  label       = "dual-stack-host-1"
  region      = local.region
  type        = local.instance_type
  image       = local.image
  tags        = local.tags
  firewall_id = linode_firewall.allow_my_ip_and_internal.id
  authorized_keys = [
    chomp(tls_private_key.ssh_key.public_key_openssh)
  ]
  root_pass = random_password.root_password.result

  metadata {
    user_data = base64encode(templatefile("${path.module}/scripts/cloud-init-hostname.yaml.tpl", {
      hostname = "host-1"
    }))
  }

  interface {
    purpose   = "vpc"
    subnet_id = linode_vpc_subnet.vpc1.id
    ipv4 {
      nat_1_1 = "any"
      vpc     = local.vpc1_address_map["host_1"]
    }
  }

  interface {
    purpose      = "vlan"
    label        = "vlan1"
    ipam_address = local.vlan_address_map["host_1"]
  }

  swap_size = 256
}

resource "linode_instance" "host_2" {
  label       = "dual-stack-host-2"
  region      = local.region
  type        = local.instance_type
  image       = local.image
  tags        = local.tags
  firewall_id = linode_firewall.allow_my_ip_and_internal.id
  authorized_keys = [
    chomp(tls_private_key.ssh_key.public_key_openssh)
  ]
  root_pass = random_password.root_password.result

  metadata {
    user_data = base64encode(templatefile("${path.module}/scripts/cloud-init-hostname.yaml.tpl", {
      hostname = "host-2"
    }))
  }

  interface {
    purpose   = "vpc"
    subnet_id = linode_vpc_subnet.vpc2.id
    ipv4 {
      nat_1_1 = "any"
      vpc     = local.vpc2_address_map["host_2"]
    }
  }

  interface {
    purpose      = "vlan"
    label        = "vlan1"
    ipam_address = local.vlan_address_map["host_2"]
  }

  swap_size = 256
}

resource "linode_instance" "host_3" {
  label       = "dual-stack-host-3"
  region      = local.region
  type        = local.instance_type
  image       = local.image
  tags        = local.tags
  firewall_id = linode_firewall.allow_my_ip_and_internal.id
  authorized_keys = [
    chomp(tls_private_key.ssh_key.public_key_openssh)
  ]
  root_pass = random_password.root_password.result

  metadata {
    user_data = base64encode(templatefile("${path.module}/scripts/cloud-init-hostname.yaml.tpl", {
      hostname = "host-3"
    }))
  }

  interface {
    purpose   = "vpc"
    subnet_id = linode_vpc_subnet.vpc2.id
    ipv4 {
      nat_1_1 = "any"
      vpc     = local.vpc2_address_map["host_3"]
    }
  }

  swap_size = 256
}
