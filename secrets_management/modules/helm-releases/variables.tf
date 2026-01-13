variable "kubeconfig" {
  description = "Base64-encoded kubeconfig from LKE cluster"
  type        = string
  sensitive   = true
}
