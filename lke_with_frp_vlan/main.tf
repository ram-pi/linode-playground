data "linode_profile" "me" {}

resource "random_password" "frp_token" {
  length  = 32
  special = false
}

locals {
  image         = var.image
  instance_type = var.instance_type
  region        = var.region
  tags          = ["frp-vlan-demo", data.linode_profile.me.username]

  is_windows = length(regexall("^[a-zA-Z]:", abspath(path.root))) > 0
  temp_path  = local.is_windows ? "$env:TEMP" : "/tmp"

  # Strip the /prefix from the VLAN IP for use as serverAddr in frpc.toml
  frp_server_vlan_ip_plain = split("/", var.frp_server_vlan_ip)[0]
}
