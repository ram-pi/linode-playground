# Cluster 01 Outputs
output "cluster_01_id" {
  value       = linode_lke_cluster.cluster_01.id
  description = "LKE Cluster 01 ID"
}

output "cluster_01_label" {
  value       = linode_lke_cluster.cluster_01.label
  description = "LKE Cluster 01 label"
}

output "cluster_01_api_endpoint" {
  value       = linode_lke_cluster.cluster_01.api_endpoints[0]
  description = "LKE Cluster 01 API endpoint"
}

output "cluster_01_kubeconfig_path" {
  value       = local_file.kubeconfig_cluster_01.filename
  description = "Path to Cluster 01 kubeconfig file"
}

# Cluster 02 Outputs
output "cluster_02_id" {
  value       = linode_lke_cluster.cluster_02.id
  description = "LKE Cluster 02 ID"
}

output "cluster_02_label" {
  value       = linode_lke_cluster.cluster_02.label
  description = "LKE Cluster 02 label"
}

output "cluster_02_api_endpoint" {
  value       = linode_lke_cluster.cluster_02.api_endpoints[0]
  description = "LKE Cluster 02 API endpoint"
}

output "cluster_02_kubeconfig_path" {
  value       = local_file.kubeconfig_cluster_02.filename
  description = "Path to Cluster 02 kubeconfig file"
}

# Combined outputs for easy access
output "kubectl_cluster_01_command" {
  value       = "export KUBECONFIG=${local_file.kubeconfig_cluster_01.filename}"
  description = "Command to set kubectl context to Cluster 01"
}

output "kubectl_cluster_02_command" {
  value       = "export KUBECONFIG=${local_file.kubeconfig_cluster_02.filename}"
  description = "Command to set kubectl context to Cluster 02"
}

output "kubectl_both_clusters_command" {
  value       = "export KUBECONFIG=${local_file.kubeconfig_cluster_01.filename}:${local_file.kubeconfig_cluster_02.filename}"
  description = "Command to set kubectl context to both clusters"
}
