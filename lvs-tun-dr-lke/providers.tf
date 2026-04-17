terraform {
  required_providers {
    linode = {
      source  = "linode/linode"
      version = "~> 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
  }
  required_version = ">= 1.8.0"
}

provider "linode" {
  token       = var.linode_token
  api_version = "v4beta"
}
