resource "linode_token" "backup_schedule" {
  label  = "backup-schedule-token"
  scopes = "linodes:read_write"
  expiry = timeadd(timestamp(), "10m")
}

# Snapshot for the Linode instance
resource "null_resource" "set_backup_schedule" {
  # Runs only after the instance is created and backups are enabled
  triggers = {
    instance_id = linode_instance.bastion.id
  }

  provisioner "local-exec" {
    # snapshot via API call using the temporary token
    command = <<EOT
      curl -X POST -H "Authorization: Bearer ${linode_token.backup_schedule.token}" \
           -H "Content-Type: application/json" \
           https://api.linode.com/v4/linode/instances/${linode_instance.bastion.id}/backups
    EOT
  }
}

# Object Storage for volume backups (optional)
resource "linode_object_storage_key" "unlimited" {
  label   = "unlimited-access-key"
  regions = [local.backup_region]
}

resource "linode_object_storage_bucket" "volume_backups" {
  label  = "volume-backups"
  region = local.backup_region
  acl    = "private"

  # Needed for lifecycle rules
  access_key = linode_object_storage_key.unlimited.access_key
  secret_key = linode_object_storage_key.unlimited.secret_key

  lifecycle_rule {
    id      = "delete-old-backups"
    enabled = true
    expiration {
      days = 30
    }
  }
}
