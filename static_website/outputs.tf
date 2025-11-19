output "website_endpoint" {
  value = <<-EOT
        # Website Endpoint URLs:
        # curl https://${linode_object_storage_bucket.demo.hostname}
        curl https://${linode_object_storage_bucket.demo.label}.website-${linode_object_storage_bucket.demo.s3_endpoint}

        # Backup Bucket Endpoint URLs:
        # curl https://${linode_object_storage_bucket.backup.hostname}
        curl https://${linode_object_storage_bucket.backup.label}.website-${linode_object_storage_bucket.backup.s3_endpoint}
    EOT
}

output "s3cmd_config" {
  value = <<-EOT
    s3cmd --access_key=${linode_object_storage_key.demo.access_key} \
          --secret_key=${linode_object_storage_key.demo.secret_key} \
          --host=${linode_object_storage_bucket.demo.s3_endpoint} \
          --host-bucket='%(bucket)s.${linode_object_storage_bucket.demo.s3_endpoint}' \
          ls s3://${linode_object_storage_bucket.demo.label}
  EOT

  sensitive = true
}

output "s3cmd_info" {
  value = <<-EOT
    s3cmd --access_key=${linode_object_storage_key.demo.access_key} \
          --secret_key=${linode_object_storage_key.demo.secret_key} \
          --host=${linode_object_storage_bucket.demo.s3_endpoint} \
          --host-bucket='%(bucket)s.${linode_object_storage_bucket.demo.s3_endpoint}' \
          info s3://${linode_object_storage_bucket.demo.label}
  EOT

  sensitive = true
}

output "s3cmd_ws_create" {
  value = <<-EOT
    s3cmd ws-create s3://${linode_object_storage_bucket.demo.label} \
      --ws-index=index.html \
      --ws-error=404.html \
      --access_key=${linode_object_storage_key.demo.access_key} \
      --secret_key=${linode_object_storage_key.demo.secret_key} \
      --host=${linode_object_storage_bucket.demo.s3_endpoint} \
      --host-bucket='%(bucket)s.${linode_object_storage_bucket.demo.s3_endpoint}'
  EOT

  sensitive = true
}

output "s3cmd_setpolicy" {
  value = <<-EOT
    s3cmd setpolicy ./policy.json s3://${linode_object_storage_bucket.demo.label} \
      --access_key=${linode_object_storage_key.demo.access_key} \
      --secret_key=${linode_object_storage_key.demo.secret_key} \
      --host=${linode_object_storage_bucket.demo.s3_endpoint} \
      --host-bucket='%(bucket)s.${linode_object_storage_bucket.demo.s3_endpoint}'
  EOT

  sensitive = true
}

output "s3cmd_delete_recursive" {
  value = <<-EOT
    # Delete all objects in the bucket (recursive delete)
    s3cmd del --recursive --force s3://${linode_object_storage_bucket.demo.label} \
      --access_key=${linode_object_storage_key.demo.access_key} \
      --secret_key=${linode_object_storage_key.demo.secret_key} \
      --host=${linode_object_storage_bucket.demo.s3_endpoint} \
      --host-bucket='%(bucket)s.${linode_object_storage_bucket.demo.s3_endpoint}'

    # Delete the bucket
    s3cmd del --recursive --force s3://${linode_object_storage_bucket.backup.label} \
      --access_key=${linode_object_storage_key.backup.access_key} \
      --secret_key=${linode_object_storage_key.backup.secret_key} \
      --host=${linode_object_storage_bucket.backup.s3_endpoint} \
      --host-bucket='%(bucket)s.${linode_object_storage_bucket.backup.s3_endpoint}'
  EOT

  sensitive = true
}

output "rclone_config" {
  value = <<-EOT
  [linode-primary]
  type = s3
  provider = Linode
  access_key_id = ${linode_object_storage_key.demo.access_key}
  secret_access_key = ${linode_object_storage_key.demo.secret_key}
  endpoint = ${linode_object_storage_bucket.demo.s3_endpoint}

  [linode-backup]
  type = s3
  provider = Linode
  access_key_id = ${linode_object_storage_key.backup.access_key}
  secret_access_key = ${linode_object_storage_key.backup.secret_key}
  endpoint = ${linode_object_storage_bucket.backup.s3_endpoint}
  EOT

  sensitive = true
}

output "rclone_cmd" {
  value = <<-EOT
  rclone sync linode-primary:${local.label} linode-backup:${local.backup_label} --progress --config=./rclone.conf
  EOT
}
