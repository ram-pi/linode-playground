resource "linode_lke_cluster" "main" {
  label       = var.lke_cluster_label
  k8s_version = var.k8s_version
  region      = local.region
  tags        = local.tags

  pool {
    type  = var.lke_node_type
    count = var.lke_node_count

    labels = {
      role = "worker"
      type = var.lke_node_type
    }
  }

  apl_enabled = false
  tier        = "standard"

  control_plane {
    high_availability = true

    acl {
      enabled = true
      addresses {
        ipv4 = var.ipv4_whitelist_cidrs
      }
    }
  }
}
