variable "ipv4_whitelist_cidrs" {
  type        = list(string)
  description = "Additional IPv4 CIDRs allowed to access instances"
  default     = []
}
