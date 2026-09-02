terraform {
  required_version = ">= 1.8.0"

  required_providers {
    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
    linode = {
      source  = "linode/linode"
      version = "~> 4.4"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}

# IPv6 VPC attributes are only exposed through the v4beta API.
provider "linode" {
  api_version = "v4beta"
}
