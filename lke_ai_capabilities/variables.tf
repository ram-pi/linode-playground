variable "ipv4_whitelist_cidrs" {
  description = "List of IPv4 CIDR blocks to whitelist for control plane access"
  type        = list(string)
  default = [
    "0.0.0.0/0"
  ]
}
