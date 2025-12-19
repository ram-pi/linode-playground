variable "ipv4_whitelist_cidrs" {
  type        = list(string)
  description = "List of IP ranges to allow access to the instances"
  default     = []
}
