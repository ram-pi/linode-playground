output "cluster_id" {
  value       = linode_lke_cluster.harbor_prefetch.id
  description = "LKE Cluster ID"
}

output "cluster_label" {
  value       = linode_lke_cluster.harbor_prefetch.label
  description = "LKE Cluster Label"
}

output "kubeconfig_path" {
  value       = local_file.kubeconfig.filename
  description = "Path to kubeconfig file"
}

output "api_endpoints" {
  value       = linode_lke_cluster.harbor_prefetch.api_endpoints
  description = "Kubernetes API endpoints"
}

output "status" {
  value       = linode_lke_cluster.harbor_prefetch.status
  description = "Cluster status"
}

output "kubeconfig" {
  value       = linode_lke_cluster.harbor_prefetch.kubeconfig
  description = "Kubeconfig (base64 encoded)"
  sensitive   = true
}
