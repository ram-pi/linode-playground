output "lke_kubeconfig" {
  description = "Base64-decoded kubeconfig for the LKE cluster"
  value       = base64decode(linode_lke_cluster.main.kubeconfig)
  sensitive   = true
}

output "proxy_public_ip" {
  description = "Public IPv4 of the HAProxy VM"
  value       = tolist(linode_instance.proxy.ipv4)[0]
}

output "client_public_ip" {
  description = "Public IPv4 of the client VM"
  value       = tolist(linode_instance.client.ipv4)[0]
}

output "ssh_command_proxy" {
  description = "SSH command for the HAProxy VM"
  value       = "ssh -i ${local_file.private_key.filename} root@${tolist(linode_instance.proxy.ipv4)[0]}"
}

output "ssh_command_client" {
  description = "SSH command for the client VM"
  value       = "ssh -i ${local_file.private_key.filename} root@${tolist(linode_instance.client.ipv4)[0]}"
}

output "nodeport_http" {
  description = "NodePort where the hello service is exposed"
  value       = var.nodeport_http
}

output "proxy_listen_port" {
  description = "Port exposed by HAProxy"
  value       = var.proxy_listen_port
}

output "verify_commands" {
  description = "Basic post-provision checks"
  value       = <<-EOT
    tofu output -raw lke_kubeconfig > kubeconfig
    export KUBECONFIG=$PWD/kubeconfig
    kubectl get nodes -o wide

    ${"ssh -i ${local_file.private_key.filename} root@${tolist(linode_instance.proxy.ipv4)[0]} \"systemctl status haproxy\""}
    ${"ssh -i ${local_file.private_key.filename} root@${tolist(linode_instance.client.ipv4)[0]} \"uname -a\""}
  EOT
}
