variable "object_storage_region" {
  type        = string
  description = "Linode Object Storage region."
  default     = "it-mil"
}

variable "bucket_label_prefix" {
  type        = string
  description = "Bucket label prefix. A random suffix is appended for uniqueness."
  default     = "signed-url-demo"
}

variable "api_key_label_prefix" {
  type        = string
  description = "Object storage key label prefix."
  default     = "signed-url-key"
}
