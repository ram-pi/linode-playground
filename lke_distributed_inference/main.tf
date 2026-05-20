resource "random_string" "suffix" {
  length  = 5
  upper   = false
  lower   = true
  numeric = true
  special = false
}

locals {
  cluster_lon_name   = "${var.name_prefix}-lon-${random_string.suffix.result}"
  cluster_fra_1_name = "${var.name_prefix}-fra-1-${random_string.suffix.result}"
  cluster_fra_2_name = "${var.name_prefix}-fra-2-${random_string.suffix.result}"

  common_tags = [
    "lke",
    "kuberay",
    "karmada",
    "distributed-inference"
  ]
}
