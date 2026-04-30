resource "linode_lke_cluster" "primary" {
  label       = local.cluster_label
  k8s_version = var.k8s_version
  region      = var.region
  control_plane {
    high_availability = false
  }

  pool {
    type  = var.node_pool_type
    count = var.node_pool_count
    autoscaler {
      min = var.node_pool_count
      max = 5
    }
    tags = ["managed"]
  }

  tags = ["bucket-mount"]
}

resource "linode_object_storage_bucket" "this" {
  label  = var.object_storage_label
  region = var.object_storage_cluster
}

resource "linode_object_storage_key" "this" {
  label = "${var.object_storage_label}-key"
}
