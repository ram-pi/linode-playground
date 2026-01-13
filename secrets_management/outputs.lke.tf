locals {
  kubeconfig_string = base64decode(linode_lke_cluster.main.kubeconfig)
  # kubeconfig        = local.kubeconfig_string != null ? yamldecode(local.kubeconfig_string) : null
}

output "lke_kubeconfig" {
  value     = base64decode(linode_lke_cluster.main.kubeconfig)
  sensitive = true
}

output "kubectl_commands" {
  value       = <<EOT
    tofu output lke_kubeconfig > kubeconfig.yaml
    export KUBECONFIG=\$(pwd)/kubeconfig.yaml
    kubectl get nodes
  EOT
  description = "Commands to configure kubectl to connect to the LKE cluster"
}
