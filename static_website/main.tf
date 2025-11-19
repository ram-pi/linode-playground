data "linode_profile" "me" {}

locals {
  region = "it-mil"
  label  = "demo"
}

resource "linode_object_storage_bucket" "demo" {
  region = local.region
  label  = local.label

  # acl = "public-read"
}

resource "linode_object_storage_key" "demo" {
  label = "${local.label}-key"

  # uncomment to grant unlimited access, needed for bucket policy setup
  # bucket_access {
  #   bucket_name = local.label
  #   region      = local.region
  #   permissions = "read_write"
  # }

  depends_on = [linode_object_storage_bucket.demo]
}

resource "linode_object_storage_object" "index" {
  bucket = linode_object_storage_bucket.demo.label
  region = local.region
  key    = "index.html"

  secret_key = linode_object_storage_key.demo.secret_key
  access_key = linode_object_storage_key.demo.access_key

  source = pathexpand("./website/index.html")

  # acl = "public-read"
}

resource "linode_object_storage_object" "not_found" {
  bucket = linode_object_storage_bucket.demo.label
  region = local.region
  key    = "404.html"

  secret_key = linode_object_storage_key.demo.secret_key
  access_key = linode_object_storage_key.demo.access_key

  source = pathexpand("./website/404.html")

  # acl = "public-read"
}

# Generate the Policy JSON file locally
resource "local_file" "bucket_policy" {
  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "arn:aws:s3:::${linode_object_storage_bucket.demo.label}/*"
      }
    ]
  })
  filename = "${path.module}/policy.json"
}

# setup public policy and website configuration
# using local-exec provisioner with s3cmd
# requires s3cmd to be installed
resource "null_resource" "setup_website" {
  triggers = {
    bucket_id = linode_object_storage_bucket.demo.id
    policy_id = local_file.bucket_policy.id
  }

  provisioner "local-exec" {
    command = <<EOT
      # 1. Apply Public Policy
      s3cmd setpolicy ${local_file.bucket_policy.filename} s3://${linode_object_storage_bucket.demo.label} \
        --access_key=${linode_object_storage_key.demo.access_key} \
        --secret_key=${linode_object_storage_key.demo.secret_key} \
        --host=${linode_object_storage_bucket.demo.s3_endpoint} \
        --host-bucket='%(bucket)s.${linode_object_storage_bucket.demo.s3_endpoint}'

      # 2. Configure Website (Index/404)
      s3cmd ws-create s3://${linode_object_storage_bucket.demo.label} \
        --acl-public \
        --ws-index=index.html \
        --ws-error=404.html \
        --access_key=${linode_object_storage_key.demo.access_key} \
        --secret_key=${linode_object_storage_key.demo.secret_key} \
        --host=${linode_object_storage_bucket.demo.s3_endpoint} \
        --host-bucket='%(bucket)s.${linode_object_storage_bucket.demo.s3_endpoint}'

      # 3. Failback: linode-cli to set website configuration if s3cmd is not working
      # linode-cli obj ws-create \
      #   --cluster ${local.region} ${local.label} \
      #   --ws-index=index.html --ws-error=404.html
    EOT
  }

  depends_on = [linode_object_storage_bucket.demo]
}
