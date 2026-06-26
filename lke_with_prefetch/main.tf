resource "linode_lke_cluster" "harbor_prefetch" {
  label       = "${var.label_prefix}-cluster"
  k8s_version = var.k8s_version
  region      = var.region
  control_plane {
    high_availability = true

    acl {
      enabled = true
      addresses {
        ipv4 = [var.acl_ipv4_whitelist]
      }
    }
  }

  tier = var.tier

  pool {
    type  = var.node_type
    count = var.node_count
  }

}

# resource "linode_lke_node_pool" "primary" {
#   cluster_id = linode_lke_cluster.harbor_prefetch.id
#   type       = var.node_type
#   count      = var.node_count
# }

# Save kubeconfig to local file
resource "local_file" "kubeconfig" {
  content  = base64decode(linode_lke_cluster.harbor_prefetch.kubeconfig)
  filename = "${path.module}/kubeconfig.yaml"

  depends_on = [linode_lke_cluster.harbor_prefetch]
}
