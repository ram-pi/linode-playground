output "lon_cluster_id" {
  description = "LKE cluster ID in gb-lon (Karmada host)"
  value       = linode_lke_cluster.cluster_lon.id
}

output "lon_cluster_label" {
  description = "LKE cluster label in gb-lon"
  value       = linode_lke_cluster.cluster_lon.label
}

output "fra_1_cluster_id" {
  description = "LKE cluster ID in de-fra-2 #1"
  value       = linode_lke_cluster.cluster_fra_1.id
}

output "fra_1_cluster_label" {
  description = "LKE cluster label in de-fra-2 #1"
  value       = linode_lke_cluster.cluster_fra_1.label
}

output "fra_2_cluster_id" {
  description = "LKE cluster ID in de-fra-2 #2"
  value       = linode_lke_cluster.cluster_fra_2.id
}

output "fra_2_cluster_label" {
  description = "LKE cluster label in de-fra-2 #2"
  value       = linode_lke_cluster.cluster_fra_2.label
}

output "lon_kubeconfig_path" {
  description = "Local file path for gb-lon kubeconfig"
  value       = local_file.kubeconfig_lon.filename
}

output "fra_1_kubeconfig_path" {
  description = "Local file path for de-fra-2-1 kubeconfig"
  value       = local_file.kubeconfig_fra_1.filename
}

output "fra_2_kubeconfig_path" {
  description = "Local file path for de-fra-2-2 kubeconfig"
  value       = local_file.kubeconfig_fra_2.filename
}

output "lon_kubeconfig" {
  description = "Raw kubeconfig for gb-lon cluster (Karmada host)"
  value       = linode_lke_cluster.cluster_lon.kubeconfig
  sensitive   = true
}

output "fra_1_kubeconfig" {
  description = "Raw kubeconfig for de-fra-2 cluster #1"
  value       = linode_lke_cluster.cluster_fra_1.kubeconfig
  sensitive   = true
}

output "fra_2_kubeconfig" {
  description = "Raw kubeconfig for de-fra-2 cluster #2"
  value       = linode_lke_cluster.cluster_fra_2.kubeconfig
  sensitive   = true
}
