resource "linode_instance" "director" {
  label  = "lvs-dr-director"
  image  = var.image
  region = local.region
  type   = var.director_instance_type
  tags   = local.tags

  authorized_keys = [
    chomp(tls_private_key.ssh_key.public_key_openssh)
  ]

  metadata {
    user_data = base64encode(templatefile("${path.module}/scripts/director-cloud-init.yaml.tpl", {
      hostname = "lvs-dr-director"
    }))
  }

  root_pass = var.root_password

  interface {
    purpose = "public"
  }

  interface {
    purpose      = "vlan"
    label        = "lvs-vlan"
    ipam_address = "10.0.0.1/24"
  }

  # Linode private IP in 192.168.128.0/17 for director-to-LKE internal traffic.
  private_ip = true
}
