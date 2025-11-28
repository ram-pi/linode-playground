locals {
  gateway_1_internal_ip = "10.10.1.2"
  gateway_2_internal_ip = "10.10.2.2"
  host_1_internal_ip    = "10.10.1.3"
  host_2_internal_ip    = "10.10.2.3"
}

### Gateway Instances ###

### Gateway-1 ###

resource "linode_instance" "gateway-site-1" {
  label  = "gateway-site-1"
  image  = "linode/ubuntu24.04"
  region = local.region_site_1
  type   = "g6-nanode-1"

  # ssh key
  authorized_keys = [
    chomp("${tls_private_key.ssh_key.public_key_openssh}")
  ]

  metadata {
    user_data = base64encode(file("./scripts/cloud-init.yaml"))
  }

  interface {
    purpose = "public"
  }

  interface {
    label        = "vlan-site-1"
    purpose      = "vlan"
    ipam_address = "${local.gateway_1_internal_ip}/24"
  }

}

### Gateway-2 ###

resource "linode_instance" "gateway-site-2" {
  label  = "gateway-site-2"
  image  = "linode/ubuntu24.04"
  region = local.region_site_2
  type   = "g6-nanode-1"

  # ssh key
  authorized_keys = [
    chomp("${tls_private_key.ssh_key.public_key_openssh}")
  ]

  metadata {
    user_data = base64encode(file("./scripts/cloud-init.yaml"))
  }

  interface {
    purpose = "public"
  }

  interface {
    label        = "vlan-site-2"
    purpose      = "vlan"
    ipam_address = "${local.gateway_2_internal_ip}/24"
  }
}

### Host Instances ###

resource "random_password" "host_root_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

### Host-1 ###

resource "linode_instance" "host-site-1" {
  label  = "host-site-1"
  region = local.region_site_1
  type   = "g6-nanode-1"

  # metadata {
  #   user_data = base64encode(
  #     templatefile("./scripts/cloud-init.2.yaml", {
  #       vlan_ip_cidr = local.host_1_internal_ip
  #   }))
  # }
}

resource "linode_instance_disk" "host-site-1" {
  label     = "host-site-1"
  linode_id = linode_instance.host-site-1.id
  #size      = linode_instance.my-host-site-1.specs.0.disk
  size  = linode_instance.host-site-1.specs.0.disk
  image = "linode/ubuntu24.04"
  # ssh key
  authorized_keys = [
    chomp("${tls_private_key.ssh_key.public_key_openssh}")
  ]
  root_pass = random_password.host_root_password.result
}

resource "linode_instance_config" "host-site-1" {
  linode_id = linode_instance.host-site-1.id
  label     = "host-site-1"

  device {
    device_name = "sda"
    disk_id     = linode_instance_disk.host-site-1.id
  }

  interface {
    label        = "vlan-site-1"
    purpose      = "vlan"
    ipam_address = "${local.host_1_internal_ip}/24"
  }

  # for netplan configuretion disable network helper
  # https://techdocs.akamai.com/cloud-computing/docs/automatically-configure-networking#enable-or-disable-network-helper
  helpers {
    network = true
  }

  booted = true
}

### Host-2 ###

resource "linode_instance" "host-site-2" {
  label  = "host-site-2"
  region = local.region_site_2
  type   = "g6-nanode-1"

  # metadata {
  #   user_data = base64encode(
  #     templatefile("./scripts/cloud-init.2.yaml", {
  #       vlan_ip_cidr = local.host_2_internal_ip
  #   }))
  # }
}

resource "linode_instance_disk" "host-site-2" {
  label     = "host-site-2"
  linode_id = linode_instance.host-site-2.id
  #size      = linode_instance.my-host-site-1.specs.0.disk
  size  = linode_instance.host-site-2.specs.0.disk
  image = "linode/ubuntu24.04"

  # ssh key
  authorized_keys = [
    chomp("${tls_private_key.ssh_key.public_key_openssh}")
  ]
  root_pass = random_password.host_root_password.result
}

resource "linode_instance_config" "host-site-2" {
  linode_id = linode_instance.host-site-2.id
  label     = "host-site-2"

  device {
    device_name = "sda"
    disk_id     = linode_instance_disk.host-site-2.id
  }

  interface {
    label        = "vlan-site-2"
    purpose      = "vlan"
    ipam_address = "${local.host_2_internal_ip}/24"
  }

  # for netplan configuretion disable network helper
  # https://techdocs.akamai.com/cloud-computing/docs/automatically-configure-networking#enable-or-disable-network-helper
  helpers {
    network = true
  }

  booted = true
}
