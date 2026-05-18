variable "project_name" {
  description = "Project prefix used for resource labels"
  type        = string
  default     = "linode-node-exporter"
}

variable "region" {
  description = "Linode region"
  type        = string
  default     = "it-mil"
}

variable "image" {
  description = "Linode image"
  type        = string
  default     = "linode/ubuntu24.04"
}

variable "vpc_cidr" {
  description = "VPC CIDR used by exporter and monitoring VMs"
  type        = string
  default     = "10.100.100.0/24"
}

variable "exporter_vpc_ip" {
  description = "Static exporter VPC IP"
  type        = string
  default     = "10.100.100.10"
}

variable "monitoring_vpc_ip" {
  description = "Static monitoring VPC IP"
  type        = string
  default     = "10.100.100.20"
}

variable "exporter_type" {
  description = "Linode plan for the exporter VM"
  type        = string
  default     = "g6-standard-1"
}

variable "monitoring_type" {
  description = "Linode plan for the monitoring VM"
  type        = string
  default     = "g6-standard-2"
}

variable "prometheus_version" {
  description = "Pinned Prometheus version"
  type        = string
  default     = "v3.11.3"
}

variable "node_exporter_version" {
  description = "Pinned Node Exporter version"
  type        = string
  default     = "v1.11.1"
}
