resource "linode_domain" "main" {
  domain    = var.domain
  type      = "master"
  soa_email = var.email
}
