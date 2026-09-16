resource "random_string" "suffix" {
  length  = 6
  lower   = true
  numeric = true
  special = false
  upper   = false
}

locals {
  cluster_label = var.name_prefix
  common_tags   = ["lke-cert-manager-csi", "enterprise", "csi-driver"]
}
