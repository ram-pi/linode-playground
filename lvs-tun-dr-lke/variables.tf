variable "linode_token" {
  description = "Linode API token (requires Linodes Read/Write scope)"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "Linode region for all resources"
  type        = string
  default     = "it-mil"
}

variable "image" {
  description = "OS image for the LVS DR VM"
  type        = string
  default     = "linode/ubuntu24.04"
}

variable "director_instance_type" {
  description = "Linode instance type for the LVS DR director VM"
  type        = string
  default     = "g6-standard-2"
}

variable "lke_cluster_label" {
  description = "LKE cluster label"
  type        = string
  default     = "lvs-dr-lke"
}

variable "k8s_version" {
  description = "Kubernetes version for the LKE cluster"
  type        = string
  default     = "1.35"
}

variable "lke_node_type" {
  description = "Linode instance type for LKE worker nodes"
  type        = string
  default     = "g6-standard-2"
}

variable "lke_node_count" {
  description = "Number of LKE worker nodes"
  type        = number
  default     = 3
}

variable "nodeport_http" {
  description = "Fixed NodePort used by the whoami service"
  type        = number
  default     = 32080
}

variable "ipv4_whitelist_cidrs" {
  description = "CIDR list allowed for SSH and LKE control-plane ACL"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "root_password" {
  description = "Root password for the director VM (must meet Linode's password requirements)"
  type        = string
  sensitive   = true
}
