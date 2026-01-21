# Object Storage Bucket for Static Website Hosting
# This configuration creates a Linode Object Storage bucket configured as a static website
#
# NOTE: The Linode Terraform provider does not natively support website configuration
# (index/error documents). The s3cmd tool is required to enable website hosting.
# See: https://github.com/linode/terraform-provider-linode/blob/main/examples/obj_static_site

resource "random_string" "bucket_suffix" {
  length  = 4
  special = false
  upper   = false
  numeric = false
}

locals {
  bucket_label = "static-site-${random_string.bucket_suffix.result}"
}

# Object Storage Bucket with public-read ACL
resource "linode_object_storage_bucket" "static_website" {
  region = local.region
  label  = local.bucket_label
  acl    = "public-read"
}

# Object Storage Access Key
resource "linode_object_storage_key" "static_website" {
  label = "${local.bucket_label}-key"

  depends_on = [linode_object_storage_bucket.static_website]
}

# Upload index.html
resource "linode_object_storage_object" "index" {
  bucket = linode_object_storage_bucket.static_website.label
  region = local.region
  key    = "index.html"
  acl    = "public-read"

  secret_key = linode_object_storage_key.static_website.secret_key
  access_key = linode_object_storage_key.static_website.access_key

  source = pathexpand("${path.module}/website/index.html")
}

# Upload 404.html (error page)
resource "linode_object_storage_object" "not_found" {
  bucket = linode_object_storage_bucket.static_website.label
  region = local.region
  key    = "404.html"
  acl    = "public-read"

  secret_key = linode_object_storage_key.static_website.secret_key
  access_key = linode_object_storage_key.static_website.access_key

  source = pathexpand("${path.module}/website/404.html")
}

# Configure website hosting (index/error pages) using s3cmd
# Requires s3cmd to be installed locally
resource "null_resource" "setup_static_website" {
  triggers = {
    bucket_id = linode_object_storage_bucket.static_website.id
  }

  provisioner "local-exec" {
    command = <<-EOT
      s3cmd ws-create s3://${linode_object_storage_bucket.static_website.label} \
        --ws-index=index.html \
        --ws-error=404.html \
        --access_key=${linode_object_storage_key.static_website.access_key} \
        --secret_key=${linode_object_storage_key.static_website.secret_key} \
        --host=${linode_object_storage_bucket.static_website.s3_endpoint} \
        --host-bucket='%(bucket)s.${linode_object_storage_bucket.static_website.s3_endpoint}'
    EOT
  }

  depends_on = [
    linode_object_storage_bucket.static_website,
    linode_object_storage_object.index,
    linode_object_storage_object.not_found
  ]
}
