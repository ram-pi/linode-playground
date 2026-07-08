terraform {
  required_providers {
    linode = {
      source  = "linode/linode"
      version = "~> 4.0"
    }
  }
}

provider "linode" {
  token       = var.linode_token
  api_version = "v4beta"
}
