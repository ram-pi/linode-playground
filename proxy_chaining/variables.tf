variable "ipv4_whitelist_cidrs" {
  description = "List of IPv4 CIDR blocks to whitelist for control plane access"
  type        = list(string)
  default = [
    "0.0.0.0/0"
  ]
}

variable "domain" {
  description = "Domain name for DNS configuration"
  type        = string
  default     = "yourdomain.com"
}

variable "email" {
  description = "Email address for DNS SOA record"
  type        = string
  default     = "admin@yourdomain.com"
}
