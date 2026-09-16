resource "linode_lke_cluster" "this" {
  label       = local.cluster_label
  region      = var.region
  k8s_version = var.k8s_version
  tier        = "enterprise"
  apl_enabled = false
  tags        = local.common_tags

  pool {
    type  = var.pool_type
    count = var.pool_count
    labels = {
      pool = "worker"
      role = "system"
    }
    tags = local.common_tags
  }

  control_plane {
    high_availability = true

    acl {
      enabled = true
      addresses {
        ipv4 = var.control_plane_ipv4_whitelist_cidrs
      }
    }
  }
}

resource "local_file" "kubeconfig" {
  filename        = "${path.module}/kubeconfig"
  content         = base64decode(linode_lke_cluster.this.kubeconfig)
  file_permission = "0600"
}
