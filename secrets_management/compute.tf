resource "random_string" "ssh_key_suffix" {
  length  = 4
  special = false
  upper   = false
}

# Generate SSH key pair
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Save private key to local file
resource "local_file" "private_key" {
  content         = tls_private_key.ssh_key.private_key_openssh
  filename        = "${local.temp_path}/id_rsa-${random_string.ssh_key_suffix.result}"
  file_permission = "0600"
}

# Save public key to local file
resource "local_file" "public_key" {
  content         = tls_private_key.ssh_key.public_key_openssh
  filename        = "${local.temp_path}/id_rsa-${random_string.ssh_key_suffix.result}.pub"
  file_permission = "0644"
}

resource "linode_instance" "host_01" {
  label  = "host-01"
  image  = local.image
  region = local.region
  type   = local.instance_type

  # ssh key
  authorized_keys = [
    chomp("${tls_private_key.ssh_key.public_key_openssh}")
  ]

  metadata {
    user_data = base64encode(templatefile("./scripts/cloud-init.yaml.tpl", {
      hostname = "host-01"
    }))
  }

  interface {
    purpose   = "vpc"
    subnet_id = linode_vpc_subnet.subnet-2.id
    ipv4 {
      nat_1_1 = "any"
    }
  }

  firewall_id = linode_firewall.allow-my-ip-and-internal.id

  tags = local.tags
}
