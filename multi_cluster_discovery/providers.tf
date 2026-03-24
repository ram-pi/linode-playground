terraform {
  required_providers {
    linode = {
      source  = "linode/linode"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.1"
    }
  }
  required_version = ">= 1.8.0"
}

provider "linode" {
  api_version = "v4beta"
}
