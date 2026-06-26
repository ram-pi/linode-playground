variable "linode_token" {
  description = "Linode API token"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "Linode region"
  type        = string
  default     = "de-fra-2"
}

variable "label_prefix" {
  description = "Prefix for resource labels"
  type        = string
  default     = "prefetch"
}

variable "node_count" {
  description = "Number of LKE nodes"
  type        = number
  default     = 4
}

variable "node_type" {
  description = "Linode instance type for LKE nodes"
  type        = string
  default     = "g6-standard-8"
}

variable "k8s_version" {
  description = "Kubernetes version; keep aligned to the latest stable LKE release"
  type        = string
  default     = "1.35"
}

variable "tier" {
  description = "LKE cluster tier"
  type        = string
  default     = "standard"
}

variable "acl_ipv4_whitelist" {
  description = "Comma-separated list of IPv4 addresses to whitelist for API access"
  type        = string
  default     = "0.0.0.0/0"
}
