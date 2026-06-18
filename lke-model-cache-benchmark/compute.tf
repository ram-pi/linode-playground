resource "linode_lke_cluster" "this" {
  label       = local.cluster_label
  region      = var.region
  k8s_version = var.k8s_version
  tier        = "standard"
  apl_enabled = false
  tags        = local.common_tags

  pool {
    type  = var.standard_pool_type
    count = var.standard_pool_count
    labels = {
      pool = "standard"
      role = "system"
    }
    tags = local.common_tags
  }

  pool {
    type  = var.gpu_pool_type
    count = var.gpu_pool_count
    labels = {
      pool = "gpu"
      role = "inference"
    }
    tags = local.common_tags
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

resource "linode_object_storage_bucket" "model" {
  label  = local.bucket_label
  region = var.object_storage_region
}

resource "linode_object_storage_key" "model" {
  label = "${local.bucket_label}-key"

  bucket_access {
    bucket_name = linode_object_storage_bucket.model.label
    region      = var.object_storage_region
    permissions = "read_write"
  }
}

resource "local_file" "kubeconfig" {
  filename        = "${path.module}/kubeconfig"
  content         = base64decode(linode_lke_cluster.this.kubeconfig)
  file_permission = "0600"
}
