terraform {
  required_version = ">= 1.8.0"

  required_providers {
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
    linode = {
      source  = "linode/linode"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

provider "linode" {}
