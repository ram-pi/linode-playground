data "linode_profile" "me" {}

data "http" "my_ip" {
  url = "https://ipv4.icanhazip.com"
}

locals {
  region        = "it-mil"
  instance_type = "g6-standard-2"
  image         = "linode/ubuntu24.04"
  tags          = ["prametta", "dev", "active-passive-vip"]

  my_ip      = chomp(data.http.my_ip.response_body)
  my_ip_     = replace(chomp(data.http.my_ip.response_body), ".", "_")
  my_ip_cidr = "${chomp(data.http.my_ip.response_body)}/32"

  private_ip_cidr = "192.168.128.0/17"
  all_cidrs       = "0.0.0.0/0"

  vlan_cidr = "172.16.1.0/24"
  vpc_cidr  = "10.10.100.0/24"

  vlan_address_map = {
    host_01 = "172.16.1.11/24"
    host_02 = "172.16.1.12/24"
    host_03 = "172.16.1.13/24"
    host_04 = "172.16.1.14/24"
  }

  vpc_address_map = {
    host_01 = "10.10.100.11"
    host_02 = "10.10.100.12"
    host_03 = "10.10.100.13"
    host_04 = "10.10.100.14"
  }

  shared_vip = "172.16.1.100"

  is_windows = length(regexall("^[a-zA-Z]:", abspath(path.root))) > 0
  temp_path  = local.is_windows ? "$env:TEMP" : "/tmp"
}
