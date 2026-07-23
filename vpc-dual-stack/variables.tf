variable "region" {
  description = "Linode region for all resources"
  type        = string
  default     = "it-mil"
}

variable "instance_type" {
  description = "Linode plan for both VMs"
  type        = string
  default     = "g6-nanode-1"
}

variable "image" {
  description = "Linode image used to boot both VMs"
  type        = string
  default     = "linode/ubuntu24.04"
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = list(string)
  default     = ["prametta", "dev", "vpc-dual-stack"]
}

variable "vpc_ipv4_cidr" {
  description = "IPv4 CIDR for the VPC subnet"
  type        = string
  default     = "10.30.0.0/24"
}

variable "vpc_ipv6_prefix" {
  description = "IPv6 prefix length to allocate to the VPC (provider/API managed)"
  type        = string
  default     = "/52"
}

variable "ssh_allowed_ipv4_cidrs" {
  description = "Additional IPv4 CIDRs allowed to SSH in"
  type        = list(string)
  default     = []
}

variable "authorized_users" {
  description = "Linode usernames whose account SSH keys are added to root authorized_keys"
  type        = list(string)
  default     = []
}

variable "vpc_interface_ipv6_public" {
  description = "Allow public IPv6 routing on the VPC interfaces"
  type        = bool
  default     = false
}
