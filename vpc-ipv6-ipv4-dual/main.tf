data "http" "my_ip" {
  url = "https://ipv4.icanhazip.com"
}

resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

locals {
  my_ip_cidr = "${chomp(data.http.my_ip.response_body)}/32"

  # Key is the short VM name, value is the host offset inside subnet_ipv4_cidr.
  vms = {
    vm1 = 10
    vm2 = 11
  }

  vm_vpc_ipv4 = { for name, host in local.vms : name => cidrhost(var.subnet_ipv4_cidr, host) }

  is_windows = length(regexall("^[a-zA-Z]:", abspath(path.root))) > 0
  temp_path  = local.is_windows ? "$env:TEMP" : "/tmp"
  key_name   = "id_rsa-${var.label_prefix}-${random_string.suffix.result}"
}

resource "tls_private_key" "ssh_key" {
  algorithm = "ED25519"
}

resource "local_file" "private_key" {
  filename        = "${local.temp_path}/${local.key_name}"
  content         = tls_private_key.ssh_key.private_key_openssh
  file_permission = "0600"
}

resource "local_file" "public_key" {
  filename        = "${local.temp_path}/${local.key_name}.pub"
  content         = tls_private_key.ssh_key.public_key_openssh
  file_permission = "0644"
}
