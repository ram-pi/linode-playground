variable "region" {
  description = "Linode region for LKE cluster"
  type        = string
  default     = "it-mil"
}

variable "cluster_label" {
  description = "Label for the LKE cluster"
  type        = string
  default     = "lke-bucket-mount"
}

variable "k8s_version" {
  description = "Kubernetes version for LKE"
  type        = string
  default     = "1.35"
}

variable "node_pool_type" {
  description = "Linode node pool type"
  type        = string
  default     = "g6-standard-4"
}

variable "node_pool_count" {
  description = "Number of nodes in the pool"
  type        = number
  default     = 3
}

variable "object_storage_label" {
  description = "Label for the Object Storage bucket"
  type        = string
  default     = "lke-bucket-mount"
}

variable "object_storage_cluster" {
  description = "Object Storage region"
  type        = string
  default     = "it-mil-1"
}
