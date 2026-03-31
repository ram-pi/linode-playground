resource "random_string" "ssh_key_suffix" {
  length  = 4
  special = false
  upper   = false
}

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  content         = tls_private_key.ssh_key.private_key_openssh
  filename        = "${local.temp_path}/id_rsa-frps-${random_string.ssh_key_suffix.result}"
  file_permission = "0600"
}

resource "local_file" "public_key" {
  content         = tls_private_key.ssh_key.public_key_openssh
  filename        = "${local.temp_path}/id_rsa-frps-${random_string.ssh_key_suffix.result}.pub"
  file_permission = "0644"
}

resource "linode_instance" "frp_server" {
  label  = "frps-server"
  image  = local.image
  region = local.region
  type   = local.instance_type
  tags   = local.tags

  authorized_keys = [
    chomp(tls_private_key.ssh_key.public_key_openssh)
  ]

  metadata {
    user_data = base64encode(templatefile("${path.module}/scripts/cloud-init.yaml.tpl", {
      hostname        = "frps-server"
      frp_version     = var.frp_version
      frp_bind_port   = var.frp_bind_port
      frp_token       = random_password.frp_token.result
      frp_remote_port = var.frp_remote_port
    }))
  }

  # Public interface — provides a public IP and SSH access
  interface {
    purpose = "public"
  }

  # VLAN interface — private channel to LKE nodes for frp control traffic
  interface {
    purpose      = "vlan"
    label        = var.vlan_label
    ipam_address = var.frp_server_vlan_ip
  }

  firewall_id = linode_firewall.frp_server.id
}
