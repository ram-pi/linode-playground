variable "name_prefix" {
  description = "Prefix used for generated resource names."
  type        = string
  default     = "lke-model-cache-benchmark"
}

variable "region" {
  description = "Linode region for all compute resources."
  type        = string
  default     = "de-fra-2"
}

variable "object_storage_region" {
  description = "Linode Object Storage region for the model bucket. For de-fra-2, the S3 endpoint hostname is de-fra-1.linodeobjects.com."
  type        = string
  default     = "de-fra-2"
}

variable "k8s_version" {
  description = "LKE Kubernetes version."
  type        = string
  default     = "1.35"
}

variable "standard_pool_type" {
  description = "Linode instance type for the standard system worker pool."
  type        = string
  default     = "g6-standard-2"
}

variable "standard_pool_count" {
  description = "Number of standard worker nodes."
  type        = number
  default     = 2
}

variable "gpu_pool_type" {
  description = "Linode instance type for the GPU worker pool."
  type        = string
  default     = "g2-gpu-rtx4000a1-m"
}

variable "gpu_pool_count" {
  description = "Number of GPU worker nodes."
  type        = number
  default     = 1
}

variable "control_plane_ipv4_whitelist_cidrs" {
  description = "IPv4 CIDR blocks allowed to reach the LKE control plane. Restrict this for production."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
