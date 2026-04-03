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
  description = "OS image for the client and proxy VMs"
  type        = string
  default     = "linode/ubuntu24.04"
}

variable "proxy_instance_type" {
  description = "Linode instance type for the HAProxy VM"
  type        = string
  default     = "g7-dedicated-64-32"
}

variable "client_instance_type" {
  description = "Linode instance type for the client VM"
  type        = string
  default     = "g7-dedicated-16-8"
}

variable "lke_node_type" {
  description = "Linode instance type for LKE worker nodes"
  type        = string
  default     = "g7-dedicated-16-8"
}

variable "lke_node_count" {
  description = "Number of LKE worker nodes"
  type        = number
  default     = 25
}

variable "k8s_version" {
  description = "Kubernetes version for the LKE cluster"
  type        = string
  default     = "1.35"
}

variable "nodeport_http" {
  description = "Fixed NodePort used by the hello service"
  type        = number
  default     = 32080
}

variable "proxy_listen_port" {
  description = "HAProxy public listener port"
  type        = number
  default     = 80
}

variable "ipv4_whitelist_cidrs" {
  description = "CIDR list for SSH/API access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
