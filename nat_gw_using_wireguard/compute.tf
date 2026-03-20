resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  content         = tls_private_key.ssh_key.private_key_openssh
  filename        = "${local.temp_path}/id_rsa_nat_gw_wg"
  file_permission = "0600"
}

resource "local_file" "public_key" {
  content         = tls_private_key.ssh_key.public_key_openssh
  filename        = "${local.temp_path}/id_rsa_nat_gw_wg.pub"
  file_permission = "0644"
}

resource "random_password" "root_password" {
  length  = 20
  special = true
}

resource "linode_instance" "nat_gateway" {
  label       = "nat-gateway-wg"
  region      = local.region
  type        = local.instance_type
  image       = local.image
  tags        = concat(local.tags, ["nat-gateway"])
  firewall_id = linode_firewall.nat_gateway.id

  authorized_keys = [chomp(tls_private_key.ssh_key.public_key_openssh)]
  root_pass       = random_password.root_password.result

  metadata {
    user_data = base64encode(templatefile("${path.module}/scripts/cloud-init-hostname.yaml.tpl", {
      hostname = "nat-gateway-wg"
    }))
  }

  interface {
    purpose   = "vpc"
    subnet_id = linode_vpc_subnet.main.id
    ipv4 {
      vpc     = local.nat_gateway_ip
      nat_1_1 = "any"
    }
  }

  swap_size = 256
}

resource "linode_instance" "private_vm" {
  label       = "private-vm-wg"
  region      = local.region
  type        = local.instance_type
  image       = local.image
  tags        = concat(local.tags, ["private-only"])
  firewall_id = linode_firewall.private_vm.id

  authorized_keys = [chomp(tls_private_key.ssh_key.public_key_openssh)]
  root_pass       = random_password.root_password.result

  metadata {
    user_data = base64encode(templatefile("${path.module}/scripts/cloud-init-hostname.yaml.tpl", {
      hostname = "private-vm-wg"
    }))
  }

  interface {
    purpose   = "vpc"
    subnet_id = linode_vpc_subnet.main.id
    ipv4 {
      vpc = local.private_vm_ip
    }
  }

  swap_size = 256
}
