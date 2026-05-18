locals {
  region = var.region

  is_windows = length(regexall("^[a-zA-Z]:", abspath(path.root))) > 0
  temp_path  = local.is_windows ? "$env:TEMP" : "/tmp"
}

data "http" "my_ip" {
  url = "https://ipv4.icanhazip.com"
}

locals {
  my_ip      = chomp(data.http.my_ip.response_body)
  my_ip_cidr = "${local.my_ip}/32"
  my_ip_slug = replace(local.my_ip, ".", "-")
}