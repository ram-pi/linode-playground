output "cluster_id" {
  description = "LKE Cluster ID"
  value       = linode_lke_cluster.main.id
}

output "cluster_label" {
  description = "LKE Cluster Label"
  value       = linode_lke_cluster.main.label
}

output "kubeconfig_path" {
  description = "Path to the local kubeconfig file"
  value       = local_file.kubeconfig.filename
}

output "api_endpoints" {
  description = "Kubernetes API endpoints"
  value       = linode_lke_cluster.main.api_endpoints
}

output "status" {
  description = "Cluster status"
  value       = linode_lke_cluster.main.status
}

output "kubeconfig" {
  description = "Kubeconfig (base64 encoded)"
  value       = linode_lke_cluster.main.kubeconfig
  sensitive   = true
}
