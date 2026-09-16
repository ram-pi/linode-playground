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
