data "linode_profile" "me" {}

data "http" "my_ip" {
  url = "https://ipv4.icanhazip.com"
}

resource "random_string" "ssh_key_suffix" {
  length  = 4
  special = false
  upper   = false
}

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

locals {
  region      = var.region
  tags        = ["lvs-dr-lke", data.linode_profile.me.username]
  my_ip_cidrs = ["${chomp(data.http.my_ip.response_body)}/32"]

  is_windows = length(regexall("^[a-zA-Z]:", abspath(path.root))) > 0
  temp_path  = local.is_windows ? "$env:TEMP" : "/tmp"
}

resource "local_file" "private_key" {
  content         = tls_private_key.ssh_key.private_key_openssh
  filename        = "${local.temp_path}/id_rsa-lvs-dr-lke-${random_string.ssh_key_suffix.result}"
  file_permission = "0600"
}

resource "local_file" "public_key" {
  content         = tls_private_key.ssh_key.public_key_openssh
  filename        = "${local.temp_path}/id_rsa-lvs-dr-lke-${random_string.ssh_key_suffix.result}.pub"
  file_permission = "0644"
}
