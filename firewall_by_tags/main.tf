data "linode_profile" "me" {}

data "http" "my_ip" {
  url = "https://ipv4.icanhazip.com"
}

locals {
  my_ip = "${chomp(data.http.my_ip.response_body)}/32"
}

# linode root password generation
resource "random_password" "vm_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "linode_instance" "demo" {
  label  = "web-server"
  type   = "g6-nanode-1"
  region = "us-east"
  image  = "linode/debian13"

  # The tag is on the Linode
  tags = ["role:prametta"]

  # password from the random password resource
  root_pass = random_password.vm_password.result

  # cloud-init configuration to install and start a web server
  metadata {
    user_data = base64encode(file("cloud_init_web_server.yaml"))
  }
}

resource "linode_firewall" "default_inbound_deny" {
  label = "inbound-deny-firewall"

  inbound_policy  = "DROP"   # Drop all other inbound traffic
  outbound_policy = "ACCEPT" # Allow all outbound traffic

  linodes = [linode_instance.demo.id]
}

resource "linode_firewall" "demo" {
  label = "prametta-firewall"

  # You define the rules for the firewall
  inbound {
    label    = "allow-http-https"
    action   = "ACCEPT"
    protocol = "TCP"
    ports    = "22, 80, 443"
    ipv4     = [local.my_ip]
  }
  inbound_policy  = "DROP"   # Drop all other inbound traffic
  outbound_policy = "ACCEPT" # Allow all outbound traffic

  # You assign the *entire firewall* to the tag,
  # not to individual Linode IDs.
  tags = ["role:prametta"]
}
