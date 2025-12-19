data "linode_profile" "me" {}

data "http" "my_ip" {
  url = "https://ipv4.icanhazip.com"
}

locals {
  region        = "it-mil"        # "gb-lon" # "fr-par" # "de-fra-2" # "it-mil"
  instance_type = "g6-standard-2" # "g6-dedicated-2" # "g6-nanode-1" # "g6-standard-2"
  image         = "linode/ubuntu24.04"
  tags          = ["prametta", "dev"]

  my_ip           = chomp(data.http.my_ip.response_body)
  my_ip_          = replace(chomp(data.http.my_ip.response_body), ".", "_")
  my_ip_cidr      = "${chomp(data.http.my_ip.response_body)}/32"
  private_ip_cidr = "192.168.128.0/17"
  all_cidrs       = "0.0.0.0/0"

  # Check if the path starts with a drive letter (e.g., "C:")
  is_windows = length(regexall("^[a-zA-Z]:", abspath(path.root))) > 0

  # Set the path based on the OS
  # Note: On Windows, we often use the environment variable $env:TEMP in PowerShell
  # or a fixed path like C:/Windows/Temp if permissions allow.
  temp_path = local.is_windows ? "$env:TEMP" : "/tmp"

  # https://techdocs.akamai.com/cloud-computing/docs/configure-failover-on-a-compute-instance#ip-sharing-availability
  dc_id_map = {
    "it-mil"   = 27
    "de-fra-2" = 47
    "fr-par"   = 19
    "gb-lon"   = 44
  }

  vlan_address_map = {
    "host_01" = "10.10.100.1/24"
    "host_02" = "10.10.100.2/24"
    "host_03" = "10.10.100.3/24"
    "host_04" = "10.10.100.4/24"
  }
}
