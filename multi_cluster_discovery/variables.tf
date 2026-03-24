variable "ipv4_whitelist_cidrs" {
  description = "List of IPv4 CIDR blocks to whitelist for control plane access"
  type        = list(string)
  default = [
    "0.0.0.0/0"
  ]
}

variable "postgres_port" {
  description = "PostgreSQL TCP port exposed by the external VM"
  type        = number
  default     = 5432
}

variable "postgres_db_name" {
  description = "Demo PostgreSQL database name"
  type        = string
  default     = "testdb"
}

variable "postgres_db_user" {
  description = "Demo PostgreSQL username"
  type        = string
  default     = "testuser"
}

variable "postgres_tls_common_name" {
  description = "Common Name used in the self-signed PostgreSQL TLS certificate"
  type        = string
  default     = "postgres-db.internal"
}
