terraform {
  required_providers {
    linode = {
      source  = "linode/linode"
      version = "~> 3.0"
    }
  }
  required_version = ">= 1.8.0"
}

locals {
  kubeconfig_data = yamldecode(base64decode(linode_lke_cluster.main.kubeconfig))
}

provider "linode" {
  api_version = "v4beta"
}
