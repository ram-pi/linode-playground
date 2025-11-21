locals {
  region = "it-mil"
}

data "linode_profile" "me" {}

data "http" "my_ip" {
  url = "https://ipv4.icanhazip.com"
}

locals {
  my_ip  = "${chomp(data.http.my_ip.response_body)}/32"
  my_ip_ = replace(chomp(data.http.my_ip.response_body), "\\.", "_")
}
