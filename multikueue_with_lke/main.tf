data "linode_profile" "me" {}

data "http" "my_ip" {
  url = "https://ipv4.icanhazip.com"
}

resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

locals {
  control_plane_region = "it-mil"
  region               = "de-fra-2"
  linode_gpu_type      = "g2-gpu-rtx4000a1-m"
  instance_type        = "g6-nanode-1"
  image                = "linode/ubuntu24.04"
  tags                 = ["prametta", "dev"]
  lke_version          = "1.34"

  my_ip           = chomp(data.http.my_ip.response_body)
  my_ip_          = replace(chomp(data.http.my_ip.response_body), ".", "_")
  my_ip_cidr      = "${chomp(data.http.my_ip.response_body)}/32"
  private_ip_cidr = "192.168.128.0/17"

  # Check if the path starts with a drive letter (e.g., "C:")
  is_windows = length(regexall("^[a-zA-Z]:", abspath(path.root))) > 0

  # Set the path based on the OS
  temp_path = local.is_windows ? "$env:TEMP" : "/tmp"

  # https://techdocs.akamai.com/cloud-computing/docs/configure-failover-on-a-compute-instance#ip-sharing-availability
  dc_id_map = {
    "it-mil"   = 27
    "de-fra-2" = 47
    "fr-par"   = 19
    "gb-lon"   = 44
  }
}
