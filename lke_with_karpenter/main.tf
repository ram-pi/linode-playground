locals {
  tags = ["lke-karpenter-demo"]
}

resource "linode_lke_cluster" "main" {
  label       = "${var.label_prefix}-cluster"
  k8s_version = var.k8s_version
  region      = var.region
  tier        = var.tier
  tags        = local.tags

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

    labels = {
      role = "worker"
      type = var.node_type
    }
  }
}

resource "local_file" "kubeconfig" {
  content         = base64decode(linode_lke_cluster.main.kubeconfig)
  filename        = "${path.module}/kubeconfig.yaml"
  file_permission = "0600"

  depends_on = [linode_lke_cluster.main]
}
