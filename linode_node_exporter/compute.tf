resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private_key" {
  content         = tls_private_key.ssh_key.private_key_openssh
  filename        = "${local.temp_path}/id_rsa"
  file_permission = "0600"
}

resource "local_file" "public_key" {
  content         = tls_private_key.ssh_key.public_key_openssh
  filename        = "${local.temp_path}/id_rsa.pub"
  file_permission = "0644"
}

resource "linode_instance" "exporter" {
  label  = "${var.project_name}-exporter"
  image  = var.image
  region = local.region
  type   = var.exporter_type

  authorized_keys = [chomp(tls_private_key.ssh_key.public_key_openssh)]

  metadata {
    user_data = base64encode(templatefile("${path.module}/configs/cloud-init-exporter.yaml.tftpl", {
      monitoring_vpc_ip         = var.monitoring_vpc_ip
      node_exporter_version_raw = var.node_exporter_version
      node_exporter_version     = trimprefix(var.node_exporter_version, "v")
    }))
  }

  interface {
    purpose   = "vpc"
    subnet_id = linode_vpc_subnet.observability.id
    ipv4 {
      vpc     = var.exporter_vpc_ip
      nat_1_1 = "any"
    }
  }

  firewall_id = linode_firewall.observability.id
}

resource "linode_instance" "monitoring" {
  label  = "${var.project_name}-monitoring"
  image  = var.image
  region = local.region
  type   = var.monitoring_type

  authorized_keys = [chomp(tls_private_key.ssh_key.public_key_openssh)]

  metadata {
    user_data = base64encode(templatefile("${path.module}/configs/cloud-init-monitoring.yaml.tftpl", {
      exporter_vpc_ip        = var.exporter_vpc_ip
      prometheus_version_raw = var.prometheus_version
      prometheus_version     = trimprefix(var.prometheus_version, "v")
    }))
  }

  interface {
    purpose   = "vpc"
    subnet_id = linode_vpc_subnet.observability.id
    ipv4 {
      vpc     = var.monitoring_vpc_ip
      nat_1_1 = "any"
    }
  }

  firewall_id = linode_firewall.observability.id
}
