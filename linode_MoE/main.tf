data "http" "my_ip" {
  url = "https://ipv4.icanhazip.com"
}

locals {
  # Keep generated SSH keys in a temporary location outside the repo.
  is_windows   = length(regexall("^[a-zA-Z]:", abspath(path.root))) > 0
  temp_path    = local.is_windows ? "$env:TEMP" : "/tmp"
  caller_ip    = chomp(data.http.my_ip.response_body)
  caller_cidr  = "${local.caller_ip}/32"
  caller_label = replace(local.caller_ip, ".", "-")
}
