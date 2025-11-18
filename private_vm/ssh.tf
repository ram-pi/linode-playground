# Generate SSH key pair
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Save private key to local file
resource "local_file" "private_key" {
  content         = tls_private_key.ssh_key.private_key_openssh
  filename        = "${path.module}/ssh-keys/id_rsa"
  file_permission = "0600"
}

# Save public key to local file
resource "local_file" "public_key" {
  content         = tls_private_key.ssh_key.public_key_openssh
  filename        = "${path.module}/ssh-keys/id_rsa.pub"
  file_permission = "0644"
}

# # Output the public key (useful for adding to Linode)
# output "ssh_public_key" {
#   value       = tls_private_key.ssh_key.public_key_openssh
#   description = "The public SSH key to use for VM access"
# }

# # Output the private key path
# output "ssh_private_key_path" {
#   value       = local_file.private_key.filename
#   description = "Path to the private SSH key file"
# }
