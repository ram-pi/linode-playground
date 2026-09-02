variable "region" {
  description = "Linode region for all resources"
  type        = string
  default     = "it-mil"
}

variable "label_prefix" {
  description = "Prefix used for the VPC and subnet labels"
  type        = string
  default     = "vpc-ipv6-ipv4-dual"
}

variable "vpc_ipv6_prefix" {
  description = "IPv6 prefix length allocated to the VPC (Linode assigns the actual range)"
  type        = string
  default     = "/52"
}

variable "subnet_ipv4_cidr" {
  description = "IPv4 CIDR for the VPC subnet"
  type        = string
  default     = "10.40.0.0/24"
}

variable "subnet_ipv6_range" {
  description = "IPv6 range for the subnet, or \"auto\" to let Linode carve it from the VPC prefix"
  type        = string
  default     = "auto"
}

variable "instance_type" {
  description = "Linode plan for the VM"
  type        = string
  default     = "g6-nanode-1"
}

variable "image" {
  description = "Linode image used to boot the VM"
  type        = string
  default     = "linode/ubuntu26.04"
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = list(string)
  default     = ["prametta", "dev", "vpc-ipv6-ipv4-dual"]
}

variable "ssh_allowed_ipv4_cidrs" {
  description = "Additional IPv4 CIDRs allowed to SSH in (your public IP is always allowed)"
  type        = list(string)
  default     = []
}

variable "authorized_users" {
  description = "Linode usernames whose account SSH keys are added to root authorized_keys"
  type        = list(string)
  default     = []
}

variable "vpc_interface_ipv6_public" {
  description = "Allow public IPv6 routing on the VPC interface"
  type        = bool
  default     = false
}
