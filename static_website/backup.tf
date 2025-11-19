resource "random_string" "backup_suffix" {
  length  = 4
  special = false
  upper   = false
  numeric = false
}

locals {
  backup_region = "fr-par"
  backup_label  = "${local.label}-backup-${random_string.backup_suffix.result}"
}

resource "linode_object_storage_bucket" "backup" {
  region = local.backup_region
  label  = local.backup_label
}

resource "linode_object_storage_key" "backup" {
  label = "${local.backup_label}-key"

  depends_on = [linode_object_storage_bucket.demo]
}

# Generate the Policy JSON file locally
resource "local_file" "backup_bucket_policy" {
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "arn:aws:s3:::${linode_object_storage_bucket.backup.label}/*"
      }
    ]
  })
  filename = "${path.module}/policy.json"
}

# setup public policy and website configuration
# using local-exec provisioner with s3cmd
# requires s3cmd to be installed
resource "null_resource" "backup_setup_website" {
  triggers = {
    bucket_id = linode_object_storage_bucket.backup.id
    policy_id = local_file.backup_bucket_policy.id
  }

  provisioner "local-exec" {
    command = <<EOT
      # 1. Apply Public Policy
      s3cmd setpolicy ${local_file.backup_bucket_policy.filename} s3://${linode_object_storage_bucket.backup.label} \
      --access_key=${linode_object_storage_key.backup.access_key} \
      --secret_key=${linode_object_storage_key.backup.secret_key} \
      --host=${linode_object_storage_bucket.backup.s3_endpoint} \
      --host-bucket='%(bucket)s.${linode_object_storage_bucket.backup.s3_endpoint}'

      # 2. Configure Website (Index/404)
      s3cmd ws-create s3://${linode_object_storage_bucket.backup.label} \
      --acl-public \
      --ws-index=index.html \
      --ws-error=404.html \
      --access_key=${linode_object_storage_key.backup.access_key} \
      --secret_key=${linode_object_storage_key.backup.secret_key} \
      --host=${linode_object_storage_bucket.backup.s3_endpoint} \
      --host-bucket='%(bucket)s.${linode_object_storage_bucket.backup.s3_endpoint}'

      # 3. Failback: linode-cli to set website configuration if s3cmd is not working
      # linode-cli obj ws-create \
      #   --cluster ${local.backup_region} ${local.backup_label} \
      #   --ws-index=index.html --ws-error=404.html
    EOT
  }

  depends_on = [ linode_object_storage_bucket.backup ]
}
