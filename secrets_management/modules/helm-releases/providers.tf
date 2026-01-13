terraform {
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
  }
}

locals {
  kubeconfig_data = yamldecode(base64decode(var.kubeconfig))
}

provider "helm" {
  kubernetes = {
    host                   = local.kubeconfig_data.clusters[0].cluster.server
    token                  = local.kubeconfig_data.users[0].user.token
    cluster_ca_certificate = base64decode(local.kubeconfig_data.clusters[0].cluster["certificate-authority-data"])
  }
}
