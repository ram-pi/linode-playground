variable "region" {
  description = "Linode region that supports LKE Enterprise"
  type        = string
  default     = "gb-lon"
}

variable "k8s_version" {
  description = "LKE Enterprise version; query current values with linode-cli lke tiered-versions-list enterprise"
  type        = string
  default     = "v1.34.6+lke2"
}

variable "node_type" {
  description = "Linode type used by the LKE worker pool"
  type        = string
  default     = "g6-standard-2"
}

variable "node_count" {
  description = "Number of LKE worker nodes"
  type        = number
  default     = 3

  validation {
    condition     = var.node_count >= 1
    error_message = "node_count must be at least 1."
  }
}

variable "client_type" {
  description = "Linode type used by the VPC client"
  type        = string
  default     = "g6-nanode-1"
}

variable "client_image" {
  description = "Image used by the VPC client"
  type        = string
  default     = "linode/ubuntu24.04"
}

variable "linode_nameservers" {
  description = "Authoritative Linode nameserver IPv4 addresses used to resolve the Linode-hosted .internal DNS zone"
  type        = list(string)
  default     = ["92.123.94.2", "92.123.94.3", "92.123.95.3", "92.123.95.4", "92.123.95.2"]
}

variable "vpc_ipv4_cidr" {
  description = "IPv4 CIDR for the primary LKE Enterprise VPC subnet"
  type        = string
  default     = "10.8.0.0/14"
}

variable "secondary_vpc_ipv4_cidr" {
  description = "IPv4 CIDR for the secondary LKE Enterprise VPC subnet"
  type        = string
  default     = "10.44.0.0/14"
}

variable "control_plane_allowed_ipv4_cidrs" {
  description = "IPv4 CIDRs allowed to access the Kubernetes control plane"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "ssh_allowed_ipv4_cidrs" {
  description = "IPv4 CIDRs allowed to SSH to the client through its 1:1 NAT address"
  type        = list(string)
  default     = []
}

variable "node_port" {
  description = "NodePort used by the hello service"
  type        = number
  default     = 32080

  validation {
    condition     = var.node_port >= 30000 && var.node_port <= 32767
    error_message = "node_port must be in the Kubernetes NodePort range 30000-32767."
  }
}

variable "tags" {
  description = "Tags applied to created Linode resources"
  type        = list(string)
  default     = ["lke-enterprise-nodeport-external-dns"]
}
