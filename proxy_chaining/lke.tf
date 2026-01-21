resource "linode_lke_cluster" "main" {

  label       = "my-lke"
  k8s_version = local.lke_version
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
      min = 3
      max = 6
    }

  }

  apl_enabled = false # Enable/Disable Akamai App Platform

  # tier = "enterprise"
  tier = "standard"

  control_plane {
    high_availability = true

    acl {
      enabled = true
      addresses {
        ipv4 = concat(var.ipv4_whitelist_cidrs, [tolist(linode_instance.host_01.ipv4[*])[0] + "/32"])
      }
    }
  }
}

# Install Helm releases via module (avoids provider cycle)
module "helm_releases" {
  source     = "./modules/helm-releases"
  kubeconfig = linode_lke_cluster.main.kubeconfig
}
