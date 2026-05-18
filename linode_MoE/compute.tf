resource "random_id" "suffix" {
  byte_length = 2
}

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  content         = tls_private_key.ssh_key.private_key_openssh
  filename        = "${local.temp_path}/id_rsa-linode-moe-${random_id.suffix.hex}"
  file_permission = "0600"
}

resource "local_file" "public_key" {
  content         = tls_private_key.ssh_key.public_key_openssh
  filename        = "${local.temp_path}/id_rsa-linode-moe-${random_id.suffix.hex}.pub"
  file_permission = "0644"
}

resource "linode_instance" "gpu_vm" {
  label  = var.vm_label
  type   = var.instance_type
  region = var.region
  image  = var.image
  tags   = var.tags

  authorized_keys = [chomp(tls_private_key.ssh_key.public_key_openssh)]
  firewall_id     = linode_firewall.vm.id

  metadata {
    user_data = base64encode(file("${path.module}/scripts/cloud-init.yaml"))
  }

  interface {
    purpose   = "vpc"
    subnet_id = linode_vpc_subnet.main.id
    ipv4 {
      nat_1_1 = "any"
    }
  }
}
