resource "linode_instance" "proxy" {
  label  = "haproxy-proxy"
  image  = var.image
  region = local.region
  type   = var.proxy_instance_type
  tags   = local.tags

  authorized_keys = [
    chomp(tls_private_key.ssh_key.public_key_openssh)
  ]

  metadata {
    user_data = base64encode(templatefile("${path.module}/scripts/proxy-cloud-init.yaml.tpl", {
      hostname = "haproxy-proxy"
    }))
  }

  interface {
    purpose = "public"
  }

}

resource "linode_instance" "client" {
  label  = "traffic-client"
  image  = var.image
  region = local.region
  type   = var.client_instance_type
  tags   = local.tags

  authorized_keys = [
    chomp(tls_private_key.ssh_key.public_key_openssh)
  ]

  metadata {
    user_data = base64encode(templatefile("${path.module}/scripts/client-cloud-init.yaml.tpl", {
      hostname = "traffic-client"
    }))
  }

  interface {
    purpose = "public"
  }

}
