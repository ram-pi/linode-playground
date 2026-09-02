resource "linode_instance" "vm" {
  for_each = local.vms

  label  = "${var.label_prefix}-${each.key}-${random_string.suffix.result}"
  region = var.region
  type   = var.instance_type

  # Required to attach standalone linode_interface resources instead of legacy config interfaces.
  interface_generation = "linode"

  authorized_keys  = [chomp(tls_private_key.ssh_key.public_key_openssh)]
  authorized_users = var.authorized_users
  tags             = var.tags

  metadata {
    user_data = base64encode(templatefile("${path.module}/scripts/cloud-init.yaml.tpl", {
      hostname = "${var.label_prefix}-${each.key}"
    }))
  }
}

resource "linode_instance_disk" "boot" {
  for_each = local.vms

  label     = "boot"
  linode_id = linode_instance.vm[each.key].id
  size      = linode_instance.vm[each.key].specs[0].disk
  image     = var.image

  # No root_pass: SSH key only.
  authorized_keys  = [chomp(tls_private_key.ssh_key.public_key_openssh)]
  authorized_users = var.authorized_users
}

# Dual-stack VPC interface: IPv4 with 1:1 NAT for public reachability, IPv6 via SLAAC.
resource "linode_interface" "vpc" {
  for_each = local.vms

  linode_id   = linode_instance.vm[each.key].id
  firewall_id = linode_firewall.main.id

  default_route = {
    ipv4 = true
    ipv6 = true
  }

  vpc = {
    subnet_id = linode_vpc_subnet.main.id

    ipv4 = {
      addresses = [
        {
          address         = local.vm_vpc_ipv4[each.key]
          primary         = true
          nat_1_1_address = "auto"
        }
      ]
    }

    ipv6 = {
      is_public = var.vpc_interface_ipv6_public

      slaac = [
        {
          range = "auto"
        }
      ]
    }
  }
}

resource "linode_instance_config" "vm" {
  for_each = local.vms

  depends_on = [linode_interface.vpc]

  linode_id = linode_instance.vm[each.key].id
  label     = "boot-config"

  device {
    device_name = "sda"
    disk_id     = linode_instance_disk.boot[each.key].id
  }

  booted = true
}
