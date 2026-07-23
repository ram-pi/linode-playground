data "http" "my_ip" {
  url = "https://ipv4.icanhazip.com"
}

resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

locals {
  my_ip      = chomp(data.http.my_ip.response_body)
  my_ip_cidr = "${local.my_ip}/32"

  vm1_vpc_ipv4 = "10.30.0.10"
  vm2_vpc_ipv4 = "10.30.0.11"

  is_windows = length(regexall("^[a-zA-Z]:", abspath(path.root))) > 0
  temp_path  = local.is_windows ? "$env:TEMP" : "/tmp"
}

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  filename        = "${local.temp_path}/id_rsa-vpc-dual-stack-${random_string.suffix.result}"
  content         = tls_private_key.ssh_key.private_key_openssh
  file_permission = "0600"
}

resource "local_file" "public_key" {
  filename        = "${local.temp_path}/id_rsa-vpc-dual-stack-${random_string.suffix.result}.pub"
  content         = tls_private_key.ssh_key.public_key_openssh
  file_permission = "0644"
}
