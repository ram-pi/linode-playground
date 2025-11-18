terraform {
  required_providers {
    linode = {
      source  = "linode/linode"
      version = "~> 3.0"
    }
    http = {
      source  = "opentofu/http"
      version = "~> 3.0"
    }
    tls = {
      source  = "opentofu/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "opentofu/local"
      version = "~> 2.0"
    }
  }
  required_version = ">= 1.8.0"
}

provider "linode" {}
