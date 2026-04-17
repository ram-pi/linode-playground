output "lke_kubeconfig" {
  description = "Base64-decoded kubeconfig for the LKE cluster"
  value       = base64decode(linode_lke_cluster.main.kubeconfig)
  sensitive   = true
}

output "director_public_ip" {
  description = "Public IPv4 of the LVS DR director VM"
  value       = tolist(linode_instance.director.ipv4)[0]
}

output "director_private_ip" {
  description = "Private IPv4 of the LVS DR director VM"
  value       = try(tolist(linode_instance.director.ipv4)[1], "")
}

output "ssh_command_director" {
  description = "SSH command for the LVS DR director VM"
  value       = "ssh -i ${local_file.private_key.filename} root@${tolist(linode_instance.director.ipv4)[0]}"
}

output "nodeport_http" {
  description = "NodePort where the hello service is exposed"
  value       = var.nodeport_http
}

output "verify_commands" {
  description = "Basic post-provision checks"
  value       = <<-EOT
    tofu output -raw lke_kubeconfig > kubeconfig
    export KUBECONFIG=$PWD/kubeconfig
    kubectl get nodes -o wide

    ${"ssh -i ${local_file.private_key.filename} root@${tolist(linode_instance.director.ipv4)[0]} \"uname -a && ip -4 addr\""}
  EOT
}
