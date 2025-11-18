# # SSH Connection Command
output "ssh_command" {
  value       = "ssh -i ${local_file.private_key.filename} root@${tolist(linode_instance.public.ipv4[*])[0]}"
  description = "SSH command to connect to the VM"
}

output "lish_command" {
  value       = "ssh -t ${data.linode_profile.me.username}@lish-${linode_instance.private.region}.linode.com ${linode_instance.private.label}"
  description = "SSH command to connect to the private VM using lish"
}
