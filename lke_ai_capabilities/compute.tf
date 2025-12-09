resource "linode_lke_cluster" "main" {
  label = "main"
  # k8s_version = "1.34" # latest version
  k8s_version = "v1.31.9+lke7" # latest enterprise version linode-cli lke tiered-versions-list enterprise
  region      = local.region

  # Due to certain restrictions in Terraform and LKE,
  # the cluster must be defined with at least one node pool.
  pool {
    type = "g6-dedicated-8"

    labels = {
      role = "worker"
      type = "g6-dedicated-8"
    }

    autoscaler {
      min = 4
      max = 6
    }

  }

  apl_enabled = false # Enable/Disable Akamai App Platform

  tier = "enterprise"

  control_plane {
    high_availability = true
    # audit_logs_enabled = true

    acl {
      enabled = true
      addresses {
        ipv4 = var.ipv4_whitelist_cidrs
      }
    }
  }
}

# resource "linode_lke_node_pool" "gpu-pool" {
#   cluster_id = linode_lke_cluster.main.id
#   type       = "g2-gpu-rtx4000a1-s"

#   node_count = 1

#   labels = {
#     role = "gpu-worker"
#     type = "g2-gpu-rtx4000a1-s"
#   }
# }
