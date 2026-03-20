terraform {
  required_providers {
    linode = {
      source  = "linode/linode"
      version = "~> 3.10"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
  }

  required_version = ">= 1.8.0"
}

provider "linode" {}
