#!/usr/bin/env python3

import os
import sys

import boto3
from botocore.client import Config


def chunked(items, size):
    for i in range(0, len(items), size):
        yield items[i : i + size]


def require_env(name):
    value = os.environ.get(name)
    if not value:
        print(f"Missing required environment variable: {name}", file=sys.stderr)
        sys.exit(1)
    return value


def main():
    bucket = require_env("LINODE_BUCKET")
    endpoint = require_env("LINODE_S3_ENDPOINT")
    access_key = require_env("LINODE_ACCESS_KEY")
    secret_key = require_env("LINODE_SECRET_KEY")
    # Linode region IDs (for example, it-mil) are not valid AWS region names.
    # Use a standard S3 signing region while targeting the Linode endpoint URL.
    signing_region = os.getenv("S3_SIGNING_REGION", "us-east-1")

    s3 = boto3.client(
        "s3",
        endpoint_url=f"https://{endpoint}",
        aws_access_key_id=access_key,
        aws_secret_access_key=secret_key,
        region_name=signing_region,
        config=Config(signature_version="s3v4"),
    )

    paginator = s3.get_paginator("list_objects_v2")
    keys = []
    for page in paginator.paginate(Bucket=bucket):
        for obj in page.get("Contents", []):
            keys.append({"Key": obj["Key"]})

    if not keys:
        print(f"Bucket '{bucket}' is already empty.")
        return

    deleted = 0
    for batch in chunked(keys, 1000):
        s3.delete_objects(Bucket=bucket, Delete={"Objects": batch, "Quiet": True})
        deleted += len(batch)

    print(f"Deleted {deleted} object(s) from bucket '{bucket}'.")


if __name__ == "__main__":
    main()
