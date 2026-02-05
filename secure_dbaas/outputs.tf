locals {
  public_host_primary = replace(linode_database_postgresql_v2.main.host_primary, "private-", "public-")
}

output "psql_connect_command" {
  value = <<-EOT
    # Private
    PGPASSWORD=${linode_database_postgresql_v2.main.root_password} psql -h ${linode_database_postgresql_v2.main.host_primary} \
      -U ${linode_database_postgresql_v2.main.root_username} -p ${linode_database_postgresql_v2.main.port} -d defaultdb

    # Public (if enabled)
    PGPASSWORD=${linode_database_postgresql_v2.main.root_password} psql -h ${local.public_host_primary} \
      -U ${linode_database_postgresql_v2.main.root_username} -p ${linode_database_postgresql_v2.main.port} -d defaultdb
  EOT

  sensitive = true
}

# SSH Connection Command
output "ssh_command" {
  value       = "ssh -i ${local_file.private_key.filename} root@${tolist(linode_instance.bastion.ipv4[*])[0]}"
  description = "SSH command to connect to the VM"
}

output "psql_database_uris" {
  value     = <<-EOT
    # postgresql://USER:PASSWORD@HOST:PORT/DATABASE_NAME
    postgresql://${linode_database_postgresql_v2.main.root_username}:${linode_database_postgresql_v2.main.root_password}@${local.public_host_primary}:${linode_database_postgresql_v2.main.port}/defaultdb
    pg_migrate --pgbin $(brew --prefix postgresql@15)/bin \
      -s postgresql://host:port/defaultdb \
      -t postgresql://host:port/defaultdb
  EOT
  sensitive = true
}
