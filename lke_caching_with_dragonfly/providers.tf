terraform {
  required_providers {
    linode = {
      source  = "linode/linode"
      version = "~> 4.8"
    }
  }
}

provider "linode" {
  token = var.linode_token
}
