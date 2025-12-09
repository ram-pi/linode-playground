locals {
  bucket_region = "eu-central"
}

# random 4 characters for unique bucket names
resource "random_string" "suffix" {
  length  = 4
  upper   = false
  lower   = true
  numeric = true
  special = false
}

# Object Storage for volume backups (optional)
resource "linode_object_storage_key" "rw-models-access-key" {
  label = "rw-models-access-key"

  bucket_access {
    bucket_name = linode_object_storage_bucket.models.label
    permissions = "read_write"
    region      = local.bucket_region
  }
}

resource "linode_object_storage_bucket" "apl-gitea" {
  label  = "apl-gitea-${random_string.suffix.result}"
  region = local.bucket_region
  acl    = "private"
}

resource "linode_object_storage_bucket" "apl-cnpg" {
  label  = "apl-cnpg-${random_string.suffix.result}"
  region = local.bucket_region
  acl    = "private"
}

resource "linode_object_storage_bucket" "apl-harbor" {
  label  = "apl-harbor-${random_string.suffix.result}"
  region = local.bucket_region
  acl    = "private"
}

resource "linode_object_storage_bucket" "apl-loki" {
  label  = "apl-loki-${random_string.suffix.result}"
  region = local.bucket_region
  acl    = "private"
}

resource "linode_object_storage_bucket" "models" {
  label  = "models-${random_string.suffix.result}"
  region = local.bucket_region
  acl    = "private"
}

# store trained models in object storage
resource "linode_object_storage_object" "model-v1" {
  bucket = linode_object_storage_bucket.models.label
  region = local.bucket_region
  key    = "model-v1"

  secret_key = linode_object_storage_key.rw-models-access-key.secret_key
  access_key = linode_object_storage_key.rw-models-access-key.access_key

  source = pathexpand("model-v1.joblib")
}

resource "linode_object_storage_object" "model-v2" {
  bucket = linode_object_storage_bucket.models.label
  region = local.bucket_region
  key    = "model-v2"

  secret_key = linode_object_storage_key.rw-models-access-key.secret_key
  access_key = linode_object_storage_key.rw-models-access-key.access_key

  source = pathexpand("model-v2.joblib")
}
