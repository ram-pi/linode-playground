output "lon_cluster_id" {
  description = "LKE cluster ID in gb-lon (Karmada host)"
  value       = linode_lke_cluster.cluster_lon.id
}

output "lon_cluster_label" {
  description = "LKE cluster label in gb-lon"
  value       = linode_lke_cluster.cluster_lon.label
}

output "fra_cluster_id" {
  description = "LKE cluster ID in de-fra-2"
  value       = linode_lke_cluster.cluster_fra.id
}

output "fra_cluster_label" {
  description = "LKE cluster label in de-fra-2"
  value       = linode_lke_cluster.cluster_fra.label
}

output "sea_cluster_id" {
  description = "LKE cluster ID in us-sea"
  value       = linode_lke_cluster.cluster_sea.id
}

output "sea_cluster_label" {
  description = "LKE cluster label in us-sea"
  value       = linode_lke_cluster.cluster_sea.label
}

output "lon_kubeconfig_path" {
  description = "Local file path for gb-lon kubeconfig"
  value       = local_file.kubeconfig_lon.filename
}

output "fra_kubeconfig_path" {
  description = "Local file path for de-fra-2 kubeconfig"
  value       = local_file.kubeconfig_fra.filename
}

output "sea_kubeconfig_path" {
  description = "Local file path for us-sea kubeconfig"
  value       = local_file.kubeconfig_sea.filename
}

output "lon_kubeconfig" {
  description = "Raw kubeconfig for gb-lon cluster (Karmada host)"
  value       = linode_lke_cluster.cluster_lon.kubeconfig
  sensitive   = true
}

output "fra_kubeconfig" {
  description = "Raw kubeconfig for de-fra-2 cluster"
  value       = linode_lke_cluster.cluster_fra.kubeconfig
  sensitive   = true
}

output "sea_kubeconfig" {
  description = "Raw kubeconfig for us-sea cluster"
  value       = linode_lke_cluster.cluster_sea.kubeconfig
  sensitive   = true
}
