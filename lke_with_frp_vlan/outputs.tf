output "ssh_command" {
  description = "SSH command to connect to the frps VM"
  value       = "ssh -i ${local_file.private_key.filename} root@${tolist(linode_instance.frp_server.ipv4)[0]}"
}

output "frp_server_public_ip" {
  description = "Public IP address of the frps VM"
  value       = tolist(linode_instance.frp_server.ipv4)[0]
}

output "frp_server_vlan_ip" {
  description = "VLAN IP address of the frps VM (without prefix length)"
  value       = local.frp_server_vlan_ip_plain
}

output "frp_admin_ui_endpoint" {
  description = "FRP admin UI endpoint on the frps host public IP"
  value       = "http://${tolist(linode_instance.frp_server.ipv4)[0]}:7500"
}

output "frp_token" {
  description = "Shared authentication token for frps/frpc (sensitive)"
  value       = random_password.frp_token.result
  sensitive   = true
}

output "lke_kubeconfig" {
  description = "Base64-decoded kubeconfig for the LKE cluster"
  value       = base64decode(linode_lke_cluster.main.kubeconfig)
  sensitive   = true
}

output "verify_commands" {
  description = "Infra verification commands (run after tofu apply, before workload install)"
  value       = <<-EOT
    # 1. Check frps is running on the VM
    ssh -i ${local_file.private_key.filename} root@${tolist(linode_instance.frp_server.ipv4)[0]} \
      "systemctl status frps && ss -tlnp | grep ${var.frp_bind_port}"

    # 2. Export kubeconfig and verify LKE nodes are Ready
    tofu output -raw lke_kubeconfig > kubeconfig
    export KUBECONFIG=$PWD/kubeconfig
    kubectl get nodes -o wide

    # 3. Access FRP admin UI (no SSH tunnel needed)
    open http://${tolist(linode_instance.frp_server.ipv4)[0]}:7500

    # → Continue with MANUAL_DEPLOYMENT.md for chart and workload installation
  EOT
}

output "vlan_label" {
  description = "VLAN label (required when installing lke-vlan-controller)"
  value       = var.vlan_label
}

output "vlan_cidr" {
  description = "VLAN CIDR (required when installing lke-vlan-controller)"
  value       = var.vlan_cidr
}
