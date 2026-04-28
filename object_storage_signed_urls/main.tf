resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

locals {
  bucket_label = "${var.bucket_label_prefix}-${random_string.suffix.result}"
}

resource "linode_object_storage_bucket" "signed_urls" {
  region = var.object_storage_region
  label  = local.bucket_label
}

resource "linode_object_storage_key" "signed_urls_rw" {
  label = "${var.api_key_label_prefix}-${random_string.suffix.result}"

  bucket_access {
    bucket_name = linode_object_storage_bucket.signed_urls.label
    region      = var.object_storage_region
    permissions = "read_write"
  }
}
