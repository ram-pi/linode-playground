variable "region" {
  description = "Linode region for the demo resources."
  type        = string
  default     = "de-fra-2"
}

variable "instance_type" {
  description = "Dual-GPU instance type for MoE benchmarking."
  type        = string
  default     = "g2-gpu-rtx4000a2-m"
}

variable "image" {
  description = "Image to use for the VM."
  type        = string
  default     = "linode/ubuntu24.04"
}

variable "vpc_label" {
  description = "VPC label."
  type        = string
  default     = "linode-moe-vpc"
}

variable "subnet_cidr" {
  description = "VPC subnet CIDR."
  type        = string
  default     = "10.80.10.0/24"
}

variable "vm_label" {
  description = "Instance label."
  type        = string
  default     = "linode-moe-gpu"
}

variable "tags" {
  description = "Tags to apply to resources."
  type        = list(string)
  default     = ["linode-playground", "linode-moe", "gpu"]
}
