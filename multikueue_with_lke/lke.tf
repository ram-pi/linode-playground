resource "linode_lke_cluster" "cluster_01" {

  label       = "lke-cluster-01-${random_string.suffix.result}"
  k8s_version = local.lke_version
  region      = local.control_plane_region
  tags        = concat(local.tags, ["cluster-01"])

  # Due to certain restrictions in Terraform and LKE,
  # the cluster must be defined with at least one node pool.
  pool {
    type = "g6-standard-2"

    labels = {
      role    = "worker"
      type    = "g6-standard-2"
      cluster = "cluster-01"
    }

    autoscaler {
      min = 2
      max = 4
    }

  }

  apl_enabled = false # Enable/Disable Akamai App Platform

  tier = "standard"

  control_plane {
    high_availability = false

    acl {
      enabled = true
      addresses {
        ipv4 = var.ipv4_whitelist_cidrs
      }
    }
  }
}

resource "linode_lke_cluster" "cluster_02" {

  label       = "lke-cluster-02-${random_string.suffix.result}"
  k8s_version = local.lke_version
  region      = local.region
  tags        = concat(local.tags, ["cluster-02"])

  # Due to certain restrictions in Terraform and LKE,
  # the cluster must be defined with at least one node pool.
  pool {
    type = "g6-standard-2"

    labels = {
      role    = "worker"
      type    = "g6-standard-2"
      cluster = "cluster-02"
    }

    autoscaler {
      min = 2
      max = 4
    }
  }

  pool {
    type = local.linode_gpu_type

    labels = {
      role    = "gpu-worker"
      type    = local.linode_gpu_type
      cluster = "cluster-02"
    }
    count = 1
  }

  apl_enabled = false # Enable/Disable Akamai App Platform

  tier = "standard"

  control_plane {
    high_availability = false

    acl {
      enabled = true
      addresses {
        ipv4 = var.ipv4_whitelist_cidrs
      }
    }
  }
}

# resource "linode_lke_node_pool" "gpu-pool" {
#   cluster_id = linode_lke_cluster.cluster_02.id
#   type       = local.linode_gpu_type

#   node_count = 1

#   labels = {
#     role = "gpu-worker"
#     type = local.linode_gpu_type
#   }
# }

# Save kubeconfig files locally
resource "local_file" "kubeconfig_cluster_01" {
  content         = base64decode(linode_lke_cluster.cluster_01.kubeconfig)
  filename        = "${path.module}/kubeconfig-cluster-01"
  file_permission = "0600"
}

resource "local_file" "kubeconfig_cluster_02" {
  content         = base64decode(linode_lke_cluster.cluster_02.kubeconfig)
  filename        = "${path.module}/kubeconfig-cluster-02"
  file_permission = "0600"
}

module "helm_releases_cluster_01" {
  source     = "./modules/helm-releases"
  kubeconfig = linode_lke_cluster.cluster_01.kubeconfig
}

module "helm_releases_cluster_02" {
  source     = "./modules/helm-releases"
  kubeconfig = linode_lke_cluster.cluster_02.kubeconfig
}
