# Manual Deployment Runbook

This runbook shows how to provision a Linode Object Storage bucket + RW API key and run the Flask API that generates signed upload and read URLs.

## Prerequisites

- `tofu` installed
- `python3` installed
- `uv` installed
- `jq` installed
- `LINODE_TOKEN` exported in your shell

```bash
export LINODE_TOKEN='your-token-here'
```

## Step 1 - Provision infrastructure

```bash
cd object_storage_signed_urls
tofu init
tofu apply -auto-approve
```

## Step 2 - Export runtime environment variables

```bash
export LINODE_BUCKET=$(tofu output -raw bucket_label)
export LINODE_REGION=$(tofu output -raw bucket_region)
export LINODE_S3_ENDPOINT=$(tofu output -raw s3_endpoint)
export LINODE_ACCESS_KEY=$(tofu output -raw access_key)
export LINODE_SECRET_KEY=$(tofu output -raw secret_key)
export FLASK_PORT=5000
```

## Step 3 - Install dependencies and start API

```bash
uv venv
uv sync
uv run app.py
```

If you used `./start.sh`, load the generated runtime env first:

```bash
source ./.runtime.env
uv run app.py
```

The API is exposed at:

```text
http://127.0.0.1:5000
```

## API Endpoints

### Health

```bash
curl http://127.0.0.1:5000/health
```

### 1) Create upload signed URL (PUT)

```bash
curl -s -X POST http://127.0.0.1:5000/api/signed-url/upload \
  -H "Content-Type: application/json" \
  -d '{
    "key": "uploads/sample.txt",
    "content_type": "text/plain",
    "expires_in": 900
  }'
```

Extract `signed_url` directly with `jq`:

```bash
UPLOAD_SIGNED_URL=$(curl -s -X POST http://127.0.0.1:5000/api/signed-url/upload \
  -H "Content-Type: application/json" \
  -d '{
    "key": "uploads/sample.txt",
    "content_type": "text/plain",
    "expires_in": 900
  }' | jq -r '.signed_url')
```

Use the returned `signed_url` to upload the file:

```bash
dd if=/dev/urandom of=sample.txt bs=1M count=10
curl --http1.1 -X PUT "$UPLOAD_SIGNED_URL" \
  -H "Content-Type: text/plain" \
  --upload-file ./sample.txt
```

Important:

- Paste the signed URL exactly as returned by the API. Do not add escape characters like `\?`, `\=` or `\&`.
- The `Content-Type` header must match the value used when creating the upload signed URL.

### 2) Create read signed URL (GET)

```bash
curl -s -X POST http://127.0.0.1:5000/api/signed-url/read \
  -H "Content-Type: application/json" \
  -d '{
    "key": "uploads/sample.txt",
    "expires_in": 900
  }'
```

Extract `signed_url` directly with `jq`:

```bash
READ_SIGNED_URL=$(curl -s -X POST http://127.0.0.1:5000/api/signed-url/read \
  -H "Content-Type: application/json" \
  -d '{
    "key": "uploads/sample.txt",
    "expires_in": 900
  }' | jq -r '.signed_url')
```

### 3) Download file using the read signed URL

```bash
curl "$READ_SIGNED_URL" --output downloaded-sample.txt
```

### 4) List issued signed URLs

```bash
# All signed URLs (including those within the 5-minute expiry grace period)
curl -s http://127.0.0.1:5000/api/signed-urls | jq

# Active (not yet expired) only
curl -s "http://127.0.0.1:5000/api/signed-urls?active=true" | jq
```

### 5) Multipart upload example (large file)

This example uploads a larger object using S3 multipart upload via `boto3`.

```bash
dd if=/dev/urandom of=large-sample.bin bs=1M count=100

uv run python - <<'PY'
import os
import boto3
from botocore.client import Config
from boto3.s3.transfer import TransferConfig

required = [
  "LINODE_BUCKET",
  "LINODE_S3_ENDPOINT",
  "LINODE_ACCESS_KEY",
  "LINODE_SECRET_KEY",
]
missing = [name for name in required if not os.getenv(name)]
if missing:
  raise SystemExit(f"Missing required env vars: {', '.join(missing)}")

bucket = os.environ["LINODE_BUCKET"]
endpoint = os.environ["LINODE_S3_ENDPOINT"]
if not endpoint.startswith("http://") and not endpoint.startswith("https://"):
  endpoint = f"https://{endpoint}"

access = os.environ["LINODE_ACCESS_KEY"]
secret = os.environ["LINODE_SECRET_KEY"]
region = os.getenv("S3_SIGNING_REGION", "us-east-1")

s3 = boto3.client(
    "s3",
    endpoint_url=endpoint,
    aws_access_key_id=access,
    aws_secret_access_key=secret,
    region_name=region,
    config=Config(signature_version="s3v4"),
)

config = TransferConfig(
    multipart_threshold=8 * 1024 * 1024,
    multipart_chunksize=8 * 1024 * 1024,
)

key = "uploads/large-sample.bin"
s3.upload_file("large-sample.bin", bucket, key, Config=config)
print(f"Uploaded multipart object: s3://{bucket}/{key}")
PY
```

To generate a read URL for the multipart object:

```bash
curl -s -X POST http://127.0.0.1:5000/api/signed-url/read \
  -H "Content-Type: application/json" \
  -d '{
    "key": "uploads/large-sample.bin",
    "expires_in": 900
  }' | jq
```

## Convenience Scripts

Launch everything:

```bash
./start.sh
```

Destroy everything:

```bash
./shutdown.sh
```

## Teardown (manual)

If not using scripts:

```bash
tofu destroy -auto-approve
```
