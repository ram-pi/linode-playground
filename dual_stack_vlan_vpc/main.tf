data "linode_profile" "me" {}

data "http" "my_ip" {
  url = "https://ipv4.icanhazip.com"
}

locals {
  region        = "it-mil"
  instance_type = "g6-standard-2"
  image         = "linode/ubuntu24.04"
  tags          = ["prametta", "dev", "dual-stack-vlan-vpc"]

  my_ip      = chomp(data.http.my_ip.response_body)
  my_ip_     = replace(chomp(data.http.my_ip.response_body), ".", "_")
  my_ip_cidr = "${chomp(data.http.my_ip.response_body)}/32"

  private_ip_cidr = "192.168.128.0/17"

  vlan_cidr = "172.16.1.0/24"
  vpc1_cidr = "10.10.100.0/24"
  vpc2_cidr = "10.10.101.0/24"

  vlan_address_map = {
    host_1 = "172.16.1.2/24"
    host_2 = "172.16.1.4/24"
  }

  vpc1_address_map = {
    host_1 = "10.10.100.2"
  }

  vpc2_address_map = {
    host_2 = "10.10.101.2"
    host_3 = "10.10.101.3"
  }

  is_windows = length(regexall("^[a-zA-Z]:", abspath(path.root))) > 0
  temp_path  = local.is_windows ? "$env:TEMP" : "/tmp"
}
