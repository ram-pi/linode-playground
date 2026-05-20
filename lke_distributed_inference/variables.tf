variable "name_prefix" {
  description = "Prefix used for generated resource names"
  type        = string
  default     = "lke-dist-inf"
}

variable "k8s_version" {
  description = "LKE Kubernetes version"
  type        = string
  default     = "v1.31.9+lke7"
}

variable "region_lon" {
  description = "Karmada control-plane region"
  type        = string
  default     = "gb-lon"
}

variable "region_fra" {
  description = "Inference worker region (both GPU clusters)"
  type        = string
  default     = "de-fra-2"
}

variable "standard_pool_type" {
  description = "Linode instance type for standard worker nodes"
  type        = string
  default     = "g6-standard-4"
}

variable "standard_pool_count" {
  description = "Node count for standard worker pool in each cluster"
  type        = number
  default     = 3
}

variable "gpu_pool_type" {
  description = "Linode instance type for GPU worker nodes"
  type        = string
  default     = "g2-gpu-rtx4000a1-m"
}

variable "gpu_pool_count" {
  description = "Node count for GPU pool in each cluster"
  type        = number
  default     = 1
}

variable "control_plane_ipv4_whitelist_cidrs" {
  description = "IPv4 CIDR blocks allowed to reach the LKE control planes"
  type        = list(string)
  default = [
    "0.0.0.0/0"
  ]
}
