variable "linode_token" {
  description = "Linode API token"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "Linode region for the LKE cluster"
  type        = string
  default     = "gb-lon"
}

variable "label_prefix" {
  description = "Prefix for resource labels"
  type        = string
  default     = "karpenter-demo"
}

variable "node_count" {
  description = "Number of LKE worker nodes"
  type        = number
  default     = 3
}

variable "node_type" {
  description = "Linode instance type for LKE worker nodes"
  type        = string
  default     = "g6-standard-2"
}

variable "k8s_version" {
  description = "Kubernetes version for the LKE cluster (Standard tier)"
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
