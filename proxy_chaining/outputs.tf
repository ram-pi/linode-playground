locals {
  kubeconfig_string = base64decode(linode_lke_cluster.main.kubeconfig)
  # kubeconfig        = local.kubeconfig_string != null ? yamldecode(local.kubeconfig_string) : null
}

# # SSH Connection Command
output "ssh_command" {
  value       = "ssh -i ${local_file.private_key.filename} root@${tolist(linode_instance.host_01.ipv4[*])[0]}"
  description = "SSH command to connect to the VM"
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

# Static Website Output
output "static_website_url" {
  value       = "https://${linode_object_storage_bucket.static_website.label}.website-${linode_object_storage_bucket.static_website.s3_endpoint}"
  description = "Public URL to access the static website"
}
