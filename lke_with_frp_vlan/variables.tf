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

variable "instance_type" {
  description = "Linode instance type for the frps VM"
  type        = string
  default     = "g6-nanode-1"
}

variable "image" {
  description = "OS image for the frps VM"
  type        = string
  default     = "linode/ubuntu24.04"
}

variable "lke_node_type" {
  description = "Linode instance type for LKE worker nodes"
  type        = string
  default     = "g6-standard-2"
}

variable "lke_node_count" {
  description = "Number of LKE worker nodes (fixed, no autoscaling)"
  type        = number
  default     = 2
}

variable "k8s_version" {
  description = "Kubernetes version for the LKE cluster"
  type        = string
  default     = "1.35"
}

variable "ipv4_whitelist_cidrs" {
  description = "List of IPv4 CIDR blocks to whitelist for SSH and LKE control plane access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "vlan_label" {
  description = "Label of the VLAN to attach to the frps VM and LKE nodes"
  type        = string
  default     = "frp-vlan"
}

variable "vlan_cidr" {
  description = "CIDR block for the VLAN (must be outside 192.168.0.0/16)"
  type        = string
  default     = "172.20.200.0/24"
}

variable "frp_server_vlan_ip" {
  description = "Static VLAN IP address (in CIDR notation) for the frps VM"
  type        = string
  default     = "172.20.200.101/24"
}

variable "frp_bind_port" {
  description = "TCP port that frps listens on for frpc connections"
  type        = number
  default     = 7000
}

variable "frp_remote_port" {
  description = "TCP port on frps where the tunneled dummy service is exposed"
  type        = number
  default     = 8080
}

variable "frp_version" {
  description = "frp release version to install on the server VM (e.g. 0.68.0)"
  type        = string
  default     = "0.68.0"
}
