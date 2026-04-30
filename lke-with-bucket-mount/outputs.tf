output "lke_cluster_id" {
  value       = linode_lke_cluster.primary.id
  description = "LKE cluster ID"
}

output "lke_kubeconfig" {
  value       = linode_lke_cluster.primary.kubeconfig
  description = "LKE cluster kubeconfig"
  sensitive   = true
}

output "lke_api_endpoints" {
  value       = linode_lke_cluster.primary.api_endpoints
  description = "LKE cluster API endpoints"
}

output "lke_status" {
  value       = linode_lke_cluster.primary.status
  description = "LKE cluster status"
}

output "object_storage_bucket_name" {
  value       = linode_object_storage_bucket.this.label
  description = "Linode Object Storage bucket name"
}

output "object_storage_bucket_region" {
  value       = linode_object_storage_bucket.this.region
  description = "Linode Object Storage bucket region/cluster"
}

output "object_storage_access_key" {
  value       = linode_object_storage_key.this.access_key
  description = "Object Storage access key"
  sensitive   = true
}

output "object_storage_secret_key" {
  value       = linode_object_storage_key.this.secret_key
  description = "Object Storage secret key"
  sensitive   = true
}

output "object_storage_endpoint" {
  value       = "https://${linode_object_storage_bucket.this.s3_endpoint}"
  description = "Object Storage endpoint"
}
