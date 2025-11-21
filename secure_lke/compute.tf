resource "linode_lke_cluster" "main" {
  label       = "main"
  k8s_version = "1.34" # latest version
  region      = local.region

  # Due to certain restrictions in Terraform and LKE,
  # the cluster must be defined with at least one node pool.
  pool {
    type = "g6-dedicated-4"

    labels = {
      role = "worker"
      type = "g6-dedicated-4"
    }

    autoscaler {
      min = 3
      max = 6
    }

  }

  vpc_id = linode_vpc.main.id

  apl_enabled = false # Enable/Disable Akamai App Platform

  control_plane {
    high_availability = true
    # audit_logs_enabled = true

    acl {
      enabled = true
      addresses {
        ipv4 = [
          # "${local.my_ip}",
          # "10.0.0.0/8"
          "0.0.0.0/0",
        ]
      }
    }
  }

  lifecycle {
    ignore_changes = [vpc_id]
  }

  depends_on = [linode_vpc.main]
}


# resource "linode_lke_node_pool" "pool-1" {
#   cluster_id = linode_lke_cluster.main.id
#   type       = "g6-dedicated-4"

#   autoscaler {
#     min = 3
#     max = 6
#   }

#   labels = {
#     role = "worker"
#     type = "g6-dedicated-4"
#   }
# }
