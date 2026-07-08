resource "linode_lke_cluster" "dragonfly_cache" {
  label       = "${var.label_prefix}-cluster"
  k8s_version = var.k8s_version
  region      = var.region
  tier        = var.tier

  control_plane {
    high_availability = true

    acl {
      enabled = true
      addresses {
        ipv4 = var.acl_ipv4_whitelist
      }
    }
  }

  pool {
    type  = var.node_type
    count = var.node_count
  }

  pool {
    type  = "g2-gpu-rtx4000a1-m"
    count = 1
  }
}



# Save kubeconfig to a local file for use by the install scripts
resource "local_file" "kubeconfig" {
  content  = base64decode(linode_lke_cluster.dragonfly_cache.kubeconfig)
  filename = "${path.module}/kubeconfig.yaml"

  depends_on = [linode_lke_cluster.dragonfly_cache]
}
