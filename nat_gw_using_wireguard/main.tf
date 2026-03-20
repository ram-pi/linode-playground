data "linode_profile" "me" {}

data "http" "my_ip" {
  url = "https://ipv4.icanhazip.com"
}

locals {
  region        = "it-mil"
  image         = "linode/ubuntu24.04"
  instance_type = "g6-nanode-1"
  tags          = ["prametta", "dev", "nat-gw-wireguard"]

  vpc_cidr         = "10.50.0.0/24"
  nat_gateway_ip   = "10.50.0.10"
  private_vm_ip    = "10.50.0.20"
  wireguard_subnet = "10.88.0.0/24"
  wireguard_server = "10.88.0.1/24"
  wireguard_client = "10.88.0.2/24"

  my_ip      = chomp(data.http.my_ip.response_body)
  my_ip_     = replace(local.my_ip, ".", "_")
  my_ip_cidr = "${local.my_ip}/32"

  is_windows = length(regexall("^[a-zA-Z]:", abspath(path.root))) > 0
  temp_path  = local.is_windows ? "$env:TEMP" : "/tmp"
}
