terraform {
  required_providers {
    linode = {
      source  = "linode/linode"
      version = "~> 3.0"
    }
    # helm = {
    #   source  = "hashicorp/helm"
    #   version = "~> 3.1"
    # }
  }
  required_version = ">= 1.8.0"
}

provider "linode" {}

# provider "helm" {
#   kubernetes = {
#     host                   = yamldecode(base64decode(linode_lke_cluster.main.kubeconfig)).clusters[0].cluster.server
#     token                  = yamldecode(base64decode(linode_lke_cluster.main.kubeconfig)).users[0].user.token
#     cluster_ca_certificate = base64decode(yamldecode(base64decode(linode_lke_cluster.main.kubeconfig)).clusters[0].cluster["certificate-authority-data"])
#   }
# }
