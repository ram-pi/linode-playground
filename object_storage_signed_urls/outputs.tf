output "bucket_label" {
  description = "Created object storage bucket label."
  value       = linode_object_storage_bucket.signed_urls.label
}

output "bucket_region" {
  description = "Bucket region."
  value       = var.object_storage_region
}

output "s3_endpoint" {
  description = "S3-compatible endpoint host for the bucket region."
  value       = linode_object_storage_bucket.signed_urls.s3_endpoint
}

output "access_key" {
  description = "Object storage access key."
  value       = linode_object_storage_key.signed_urls_rw.access_key
  sensitive   = true
}

output "secret_key" {
  description = "Object storage secret key."
  value       = linode_object_storage_key.signed_urls_rw.secret_key
  sensitive   = true
}
