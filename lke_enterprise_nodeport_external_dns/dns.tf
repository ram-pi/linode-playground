resource "linode_domain" "main" {
  domain    = "lke-${linode_vpc.main.id}.internal"
  type      = "master"
  soa_email = "hostmaster@lke-${linode_vpc.main.id}.internal"
}
