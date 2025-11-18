variable "vpc_region" {
  description = "The region where the VPC will be created"
  type        = string
  default     = "it-mil"
}

variable "vm_size" {
  description = "The size/type of the virtual machine"
  type        = string
  default     = "g6-nanode-1"
}

variable "vm_image" {
  description = "The OS image for the virtual machine"
  type        = string
  default     = "linode/debian13"
}
