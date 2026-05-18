locals {
  public_ip  = tolist(linode_instance.gpu_vm.ipv4)[0]
  private_ip = try(linode_instance.gpu_vm.private_ip_address, "")
}

output "instance_type" {
  value       = var.instance_type
  description = "Instance type used for the VM."
}

output "public_ip" {
  value       = local.public_ip
  description = "Public IP address for SSH access."
}

output "private_ip" {
  value       = local.private_ip
  description = "Private IP address in the VPC subnet."
}

output "ssh_private_key_path" {
  value       = local_file.private_key.filename
  description = "Path to generated private key."
}

output "ssh_command" {
  value       = "ssh -i ${local_file.private_key.filename} root@${local.public_ip}"
  description = "SSH command to access the GPU VM."
}

output "cloud_init_log_command" {
  value       = "tail -f /var/log/cloud-init-output.log"
  description = "Command to check cloud-init progress once on the VM."
}
