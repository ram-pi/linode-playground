resource "linode_instance" "vm1" {
  label  = "vpc-dual-stack-vm1-${random_string.suffix.result}"
  region = var.region
  type   = var.instance_type
  image  = var.image

  authorized_keys  = [chomp(tls_private_key.ssh_key.public_key_openssh)]
  authorized_users = var.authorized_users
  tags             = var.tags

  metadata {
    user_data = base64encode(templatefile("${path.module}/scripts/cloud-init.yaml.tpl", {
      hostname = "vpc-dual-stack-vm1"
    }))
  }

  interface {
    purpose   = "vpc"
    subnet_id = linode_vpc_subnet.main.id

    ipv4 {
      nat_1_1 = "any"
      vpc     = local.vm1_vpc_ipv4
    }

    ipv6 {
      is_public = var.vpc_interface_ipv6_public
      slaac {
        range = "auto"
      }
    }
  }

  interface {
    purpose      = "vlan"
    label        = local.vlan_label
    ipam_address = local.vm1_vlan_ipam
  }

  firewall_id = linode_firewall.main.id
}

resource "linode_instance" "vm2" {
  label  = "vpc-dual-stack-vm2-${random_string.suffix.result}"
  region = var.region
  type   = var.instance_type
  image  = var.image

  authorized_keys  = [chomp(tls_private_key.ssh_key.public_key_openssh)]
  authorized_users = var.authorized_users
  tags             = var.tags

  metadata {
    user_data = base64encode(templatefile("${path.module}/scripts/cloud-init.yaml.tpl", {
      hostname = "vpc-dual-stack-vm2"
    }))
  }

  interface {
    purpose   = "vpc"
    subnet_id = linode_vpc_subnet.main.id

    ipv4 {
      nat_1_1 = "any"
      vpc     = local.vm2_vpc_ipv4
    }

    ipv6 {
      is_public = var.vpc_interface_ipv6_public
      slaac {
        range = "auto"
      }
    }
  }

  interface {
    purpose      = "vlan"
    label        = local.vlan_label
    ipam_address = local.vm2_vlan_ipam
  }

  firewall_id = linode_firewall.main.id
}

resource "linode_instance" "vm3" {
  label  = "vpc-dual-stack-vm3-${random_string.suffix.result}"
  region = var.region
  type   = var.instance_type
  image  = var.image

  authorized_keys  = [chomp(tls_private_key.ssh_key.public_key_openssh)]
  authorized_users = var.authorized_users
  tags             = var.tags

  metadata {
    user_data = base64encode(templatefile("${path.module}/scripts/cloud-init.yaml.tpl", {
      hostname = "vpc-dual-stack-vm3"
    }))
  }

  interface {
    purpose   = "vpc"
    subnet_id = linode_vpc_subnet.main.id

    ipv4 {
      nat_1_1 = "any"
      vpc     = local.vm3_vpc_ipv4
    }

    ipv6 {
      is_public = var.vpc_interface_ipv6_public
      slaac {
        range = "auto"
      }
    }
  }

  interface {
    purpose      = "vlan"
    label        = local.vlan_label
    ipam_address = local.vm3_vlan_ipam
  }

  firewall_id = linode_firewall.main.id
}
