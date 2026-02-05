locals {
  # Check if the path starts with a drive letter (e.g., "C:")
  is_windows = length(regexall("^[a-zA-Z]:", abspath(path.root))) > 0

  # Set the path based on the OS
  # Note: On Windows, we often use the environment variable $env:TEMP in PowerShell
  # or a fixed path like C:/Windows/Temp if permissions allow.
  temp_path       = local.is_windows ? "$env:TEMP" : "/tmp"
  linode_gpu_type = "g2-gpu-rtx4000a2-m"
  linode_image    = "linode/ubuntu24.04"
}

# Generate SSH key pair
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "random_id" "suffix" {
  byte_length = 2
}

# Save private key to local file
resource "local_file" "private_key" {
  content         = tls_private_key.ssh_key.private_key_openssh
  filename        = "${local.temp_path}/id_rsa-${random_id.suffix.dec}"
  file_permission = "0600"
}

# Save public key to local file
resource "local_file" "public_key" {
  content         = tls_private_key.ssh_key.public_key_openssh
  filename        = "${local.temp_path}/id_rsa-${random_id.suffix.dec}.pub"
  file_permission = "0644"
}

resource "linode_instance" "bastion" {
  label  = "bastion"
  image  = "linode/ubuntu24.04"
  region = local.region
  type   = local.linode_gpu_type

  # ssh key
  authorized_keys = [
    chomp("${tls_private_key.ssh_key.public_key_openssh}")
  ]

  metadata {
    user_data = base64encode(file("./scripts/cloud-init.yaml"))
  }

  interface {
    purpose   = "vpc"
    subnet_id = linode_vpc_subnet.subnet-2.id
    ipv4 {
      nat_1_1 = "any"
    }
  }

  firewall_id = linode_firewall.allow-my-ip-and-internal.id
}
