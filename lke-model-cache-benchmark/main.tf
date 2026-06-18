resource "random_string" "suffix" {
  length  = 6
  lower   = true
  numeric = true
  special = false
  upper   = false
}

locals {
  cluster_label = var.name_prefix
  bucket_label  = "${var.name_prefix}-${random_string.suffix.result}"
  common_tags   = ["lke-model-cache-benchmark", "gpu", "object-storage"]
}
