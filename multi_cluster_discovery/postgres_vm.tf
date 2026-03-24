resource "random_password" "postgres_root_password" {
  length  = 24
  special = true
}

resource "random_password" "postgres_db_password" {
  length  = 24
  special = false
}

resource "tls_private_key" "postgres_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "postgres_private_key" {
  content         = tls_private_key.postgres_ssh_key.private_key_openssh
  filename        = "${local.temp_path}/postgres_vm_id_rsa"
  file_permission = "0600"
}

resource "local_file" "postgres_public_key" {
  content         = tls_private_key.postgres_ssh_key.public_key_openssh
  filename        = "${local.temp_path}/postgres_vm_id_rsa.pub"
  file_permission = "0644"
}

resource "tls_private_key" "postgres_tls" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "postgres_server" {
  private_key_pem       = tls_private_key.postgres_tls.private_key_pem
  validity_period_hours = 24 * 365
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth"
  ]

  subject {
    common_name  = var.postgres_tls_common_name
    organization = "linode-playground"
  }
}

resource "linode_instance" "postgres_vm" {
  label     = "postgres-vm-${random_string.suffix.result}"
  region    = local.region
  type      = local.instance_type
  image     = local.image
  root_pass = random_password.postgres_root_password.result
  tags      = concat(local.tags, ["postgres", "external-db"])

  authorized_keys = [
    chomp(tls_private_key.postgres_ssh_key.public_key_openssh)
  ]

  private_ip = true

  metadata {
    user_data = base64encode(templatefile("${path.module}/scripts/cloud-init-postgres.yaml.tpl", {
      postgres_server_key_b64  = base64encode(tls_private_key.postgres_tls.private_key_pem)
      postgres_server_cert_b64 = base64encode(tls_self_signed_cert.postgres_server.cert_pem)
      postgres_ca_cert_b64     = base64encode(tls_self_signed_cert.postgres_server.cert_pem)
      postgres_user            = var.postgres_db_user
      postgres_password        = random_password.postgres_db_password.result
      postgres_db_name         = var.postgres_db_name
      postgres_port            = var.postgres_port
    }))
  }
}

resource "local_file" "postgres_server_ca" {
  content         = tls_self_signed_cert.postgres_server.cert_pem
  filename        = "${path.module}/certs/postgresql-ca.crt"
  file_permission = "0644"
}
