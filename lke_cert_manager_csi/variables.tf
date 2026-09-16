variable "name_prefix" {
  description = "Prefix used for generated resource names."
  type        = string
  default     = "lke-cert-manager-csi"
}

variable "region" {
  description = "Linode region for the LKE cluster."
  type        = string
  default     = "de-fra-2"
}

variable "k8s_version" {
  description = "LKE Enterprise Kubernetes version. Query the latest with `lin lke tiered-versions-list enterprise --text`."
  type        = string
  default     = "v1.34.6+lke2"
}

variable "pool_type" {
  description = "Linode instance type for the worker pool."
  type        = string
  default     = "g6-standard-2"
}

variable "pool_count" {
  description = "Number of worker nodes."
  type        = number
  default     = 2
}

variable "control_plane_ipv4_whitelist_cidrs" {
  description = "IPv4 CIDR blocks allowed to reach the LKE control plane. Restrict this for production."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "cert_duration" {
  description = "Validity duration of the per-node client certificates issued by the cert-manager CSI driver."
  type        = string
  default     = "30m"
}
