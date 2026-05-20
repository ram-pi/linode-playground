# Cluster 1 — gb-lon: Karmada control-plane host, no GPU
resource "linode_lke_cluster" "cluster_lon" {
  label       = local.cluster_lon_name
  region      = var.region_lon
  k8s_version = var.k8s_version
  tier        = "standard"
  apl_enabled = false
  tags        = concat(local.common_tags, ["region-lon", "karmada-host"])

  pool {
    type  = var.standard_pool_type
    count = var.standard_pool_count
    labels = {
      role    = "worker"
      region  = var.region_lon
      cluster = "lon"
      pool    = "standard"
    }
  }

  control_plane {
    high_availability = false

    acl {
      enabled = true
      addresses {
        ipv4 = var.control_plane_ipv4_whitelist_cidrs
      }
    }
  }
}

# Cluster 2 — de-fra-2 #1: Karmada member, standard + GPU
resource "linode_lke_cluster" "cluster_fra_1" {
  label       = local.cluster_fra_1_name
  region      = var.region_fra
  k8s_version = var.k8s_version
  tier        = "standard"
  apl_enabled = false
  tags        = concat(local.common_tags, ["region-fra", "karmada-member"])

  pool {
    type  = var.standard_pool_type
    count = var.standard_pool_count
    labels = {
      role    = "worker"
      region  = var.region_fra
      cluster = "fra-1"
      pool    = "standard"
    }
  }

  pool {
    type  = var.gpu_pool_type
    count = var.gpu_pool_count
    labels = {
      role    = "gpu-worker"
      region  = var.region_fra
      cluster = "fra-1"
      pool    = "gpu"
    }
  }

  control_plane {
    high_availability = false

    acl {
      enabled = true
      addresses {
        ipv4 = var.control_plane_ipv4_whitelist_cidrs
      }
    }
  }
}

# Cluster 3 — de-fra-2 #2: Karmada member, standard + GPU
resource "linode_lke_cluster" "cluster_fra_2" {
  label       = local.cluster_fra_2_name
  region      = var.region_fra
  k8s_version = var.k8s_version
  tier        = "standard"
  apl_enabled = false
  tags        = concat(local.common_tags, ["region-fra", "karmada-member"])

  pool {
    type  = var.standard_pool_type
    count = var.standard_pool_count
    labels = {
      role    = "worker"
      region  = var.region_fra
      cluster = "fra-2"
      pool    = "standard"
    }
  }

  pool {
    type  = var.gpu_pool_type
    count = var.gpu_pool_count
    labels = {
      role    = "gpu-worker"
      region  = var.region_fra
      cluster = "fra-2"
      pool    = "gpu"
    }
  }

  control_plane {
    high_availability = false

    acl {
      enabled = true
      addresses {
        ipv4 = var.control_plane_ipv4_whitelist_cidrs
      }
    }
  }
}

resource "local_file" "kubeconfig_lon" {
  filename        = "${path.module}/kubeconfig-gb-lon"
  content         = base64decode(linode_lke_cluster.cluster_lon.kubeconfig)
  file_permission = "0600"
}

resource "local_file" "kubeconfig_fra_1" {
  filename        = "${path.module}/kubeconfig-de-fra-2-1"
  content         = base64decode(linode_lke_cluster.cluster_fra_1.kubeconfig)
  file_permission = "0600"
}

resource "local_file" "kubeconfig_fra_2" {
  filename        = "${path.module}/kubeconfig-de-fra-2-2"
  content         = base64decode(linode_lke_cluster.cluster_fra_2.kubeconfig)
  file_permission = "0600"
}
