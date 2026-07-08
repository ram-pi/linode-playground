variable "linode_token" {
  description = "Linode API token"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "Linode region for the LKE cluster"
  type        = string
  default     = "us-ord"
}

variable "label_prefix" {
  description = "Prefix for resource labels"
  type        = string
  default     = "dragonfly-cache"
}

variable "node_count" {
  description = "Number of LKE worker nodes"
  type        = number
  default     = 3
}

variable "node_type" {
  description = "Linode instance type for LKE nodes"
  type        = string
  default     = "g7-dedicated-8-4"
}

variable "k8s_version" {
  description = "Kubernetes version (Standard tier: major.minor format, e.g. 1.35)"
  type        = string
  default     = "1.35"
}

variable "tier" {
  description = "LKE cluster tier"
  type        = string
  default     = "standard"
}

variable "acl_ipv4_whitelist" {
  description = "List of IPv4 CIDRs to whitelist for API server access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
