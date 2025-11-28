locals {
  region_site_1 = "it-mil"
  region_site_2 = "fr-par"
}

data "linode_profile" "me" {}

data "http" "my_ip" {
  url = "https://ipv4.icanhazip.com"
}

locals {
  my_ip      = chomp(data.http.my_ip.response_body)
  my_ip_     = replace(chomp(data.http.my_ip.response_body), ".", "_")
  my_ip_cidr = "${chomp(data.http.my_ip.response_body)}/32"
}
