resource "linode_instance" "client" {
  for_each = local.deployments

  label                = each.value.client_label
  region               = var.region
  type                 = var.client_type
  interface_generation = "linode"
  tags                 = var.tags

  metadata {
    user_data = base64encode(templatefile("${path.module}/scripts/cloud-init.yaml.tpl", {
      dns_zone    = linode_domain.main.domain
      nameservers = join(" ", var.linode_nameservers)
    }))
  }
}

resource "linode_instance_disk" "client" {
  for_each = local.deployments

  label     = "boot"
  linode_id = linode_instance.client[each.key].id
  size      = linode_instance.client[each.key].specs[0].disk
  image     = var.client_image

  authorized_keys = [chomp(tls_private_key.client.public_key_openssh)]
}

resource "linode_interface" "client" {
  for_each = local.deployments

  linode_id   = linode_instance.client[each.key].id
  firewall_id = linode_firewall.client.id

  default_route = {
    ipv4 = true
    ipv6 = true
  }

  vpc = {
    subnet_id = linode_vpc_subnet.main[each.key].id

    ipv4 = {
      addresses = [{
        primary         = true
        nat_1_1_address = "auto"
      }]
    }

    ipv6 = {
      is_public = true
      slaac = [{
        range = "auto"
      }]
    }
  }
}

resource "linode_instance_config" "client" {
  for_each = local.deployments

  depends_on = [linode_interface.client]

  linode_id = linode_instance.client[each.key].id
  label     = "boot"
  kernel    = "linode/latest-64bit"

  device {
    device_name = "sda"
    disk_id     = linode_instance_disk.client[each.key].id
  }

  booted = true
}
