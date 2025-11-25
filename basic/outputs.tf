locals {}

# # SSH Connection Command
output "ssh_command" {
  value       = "ssh -i ${local_file.private_key.filename} root@${tolist(linode_instance.bastion.ipv4[*])[0]}"
  description = "SSH command to connect to the VM"
}
