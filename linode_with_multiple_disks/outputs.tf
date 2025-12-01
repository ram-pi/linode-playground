locals {}

### SSH Connection Command
output "ssh_command" {
  value       = "ssh -i ${local_file.private_key.filename} root@${tolist(linode_instance.bastion.ipv4[*])[0]}"
  description = "SSH command to connect to the VM"
}

### Linode s3 endpoint and bucket info
output "script_env_vars" {
  value     = <<-EOT
    # Linode Object Storage Bucket Info
    BACKUP_LABEL=${linode_object_storage_bucket.volume_backups.label} \
    SOURCE_DIR="/mnt/volume1" \
    S3_ENDPOINT=${linode_object_storage_bucket.volume_backups.s3_endpoint} \
    LINODE_ACCESS_KEY=${linode_object_storage_key.unlimited.access_key} \
    LINODE_SECRET_KEY=${linode_object_storage_key.unlimited.secret_key} \
    /root/backup.sh
  EOT
  sensitive = true
}

### print the scp command to save the scripts/backup.sh to the bastion host
output "scp_backup_script_command" {
  value       = "scp -i ${local_file.private_key.filename} ./scripts/backup.sh root@${tolist(linode_instance.bastion.ipv4[*])[0]}:/root/backup.sh"
  description = "SCP command to copy the backup script to the VM"
}

### metrics and web UI rclone endpoints
output "rclone_endpoints" {
  value = <<-EOT
    # Rclone Metrics and Web UI Endpoints
    Metrics: http://${tolist(linode_instance.bastion.ipv4[*])[0]}:5572/metrics
    Web UI:  http://${tolist(linode_instance.bastion.ipv4[*])[0]}:5572
  EOT
}


### s3cmd command to empty buckets
output "s3cmd_empty_buckets_command" {
  #   s3cmd del --recursive --force s3://your-bucket-name \
  # --host=us-east-1.linodeobjects.com \
  # --host-bucket='%(bucket)s.us-east-1.linodeobjects.com' \
  # --access_key=YOUR_KEY \
  # --secret_key=YOUR_SECRET
  value       = <<-EOT
    s3cmd \
      --access_key=${linode_object_storage_key.unlimited.access_key} \
      --secret_key=${linode_object_storage_key.unlimited.secret_key} \
      --host=${linode_object_storage_bucket.volume_backups.s3_endpoint} \
      --host-bucket='%(bucket)s.${linode_object_storage_bucket.volume_backups.s3_endpoint}' \
      del s3://${linode_object_storage_bucket.volume_backups.label} --recursive --force
  EOT
  description = "s3cmd command to empty the object storage bucket"
  sensitive   = true
}
