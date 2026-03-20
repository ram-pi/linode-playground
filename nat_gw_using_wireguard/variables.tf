variable "ipv4_whitelist_cidrs" {
  description = "Additional IPv4 CIDRs allowed to access SSH on the NAT gateway"
  type        = list(string)
  default     = []
}
