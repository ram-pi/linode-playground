resource "random_string" "suffix" {
  length  = 5
  upper   = false
  lower   = true
  numeric = true
  special = false
}

locals {
  cluster_lon_name = "${var.name_prefix}-lon-${random_string.suffix.result}"
  cluster_fra_name = "${var.name_prefix}-fra-${random_string.suffix.result}"
  cluster_sea_name = "${var.name_prefix}-sea-${random_string.suffix.result}"

  common_tags = [
    "lke",
    "kuberay",
    "karmada",
    "distributed-inference",
    "akamai-summit"
  ]
}

moved {
  from = linode_lke_cluster.cluster_fra_1
  to   = linode_lke_cluster.cluster_fra
}

moved {
  from = linode_lke_cluster.cluster_fra_2
  to   = linode_lke_cluster.cluster_sea
}

moved {
  from = local_file.kubeconfig_fra_1
  to   = local_file.kubeconfig_fra
}

moved {
  from = local_file.kubeconfig_fra_2
  to   = local_file.kubeconfig_sea
}
