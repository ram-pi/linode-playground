output "lke_cluster_id" {
  description = "LKE cluster ID."
  value       = linode_lke_cluster.this.id
}

output "lke_status" {
  description = "LKE cluster status."
  value       = linode_lke_cluster.this.status
}

output "lke_api_endpoints" {
  description = "LKE cluster API endpoints."
  value       = linode_lke_cluster.this.api_endpoints
}

output "lke_kubeconfig" {
  description = "Base64-encoded LKE kubeconfig."
  value       = linode_lke_cluster.this.kubeconfig
  sensitive   = true
}

output "object_storage_bucket_name" {
  description = "Linode Object Storage bucket name."
  value       = linode_object_storage_bucket.model.label
}

output "object_storage_bucket_region" {
  description = "Linode Object Storage bucket region."
  value       = linode_object_storage_bucket.model.region
}

output "object_storage_endpoint" {
  description = "Linode Object Storage S3 endpoint."
  value       = "https://${linode_object_storage_bucket.model.s3_endpoint}"
}

output "object_storage_access_key" {
  description = "Object Storage access key."
  value       = linode_object_storage_key.model.access_key
  sensitive   = true
}

output "object_storage_secret_key" {
  description = "Object Storage secret key."
  value       = linode_object_storage_key.model.secret_key
  sensitive   = true
}
