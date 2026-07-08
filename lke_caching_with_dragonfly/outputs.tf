output "cluster_id" {
  value       = linode_lke_cluster.dragonfly_cache.id
  description = "LKE Cluster ID"
}

output "cluster_label" {
  value       = linode_lke_cluster.dragonfly_cache.label
  description = "LKE Cluster Label"
}

output "kubeconfig_path" {
  value       = local_file.kubeconfig.filename
  description = "Path to the local kubeconfig file"
}

output "api_endpoints" {
  value       = linode_lke_cluster.dragonfly_cache.api_endpoints
  description = "Kubernetes API endpoints"
}

output "status" {
  value       = linode_lke_cluster.dragonfly_cache.status
  description = "Cluster status"
}

output "kubeconfig" {
  value       = linode_lke_cluster.dragonfly_cache.kubeconfig
  description = "Kubeconfig (base64 encoded)"
  sensitive   = true
}
