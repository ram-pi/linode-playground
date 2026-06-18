terraform {
  required_version = ">= 1.8.0"

  required_providers {
    linode = {
      source  = "linode/linode"
      version = "~> 3.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "linode" {
  api_version = "v4beta"
}
