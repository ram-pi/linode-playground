#!/usr/bin/env python3
# /// script
# dependencies = ["boto3>=1.34"]
# ///
from __future__ import annotations

import os

import boto3
from botocore.config import Config


def env(name: str) -> str:
    value = os.environ.get(name)
    if not value:
        raise SystemExit(f"Missing required environment variable: {name}")
    return value


def main() -> None:
    bucket = env("LINODE_BUCKET")
    client = boto3.client(
        "s3",
        endpoint_url=env("LINODE_ENDPOINT"),
        aws_access_key_id=env("LINODE_ACCESS_KEY"),
        aws_secret_access_key=env("LINODE_SECRET_KEY"),
        config=Config(
            signature_version="s3v4",
            s3={"addressing_style": "path"},
            request_checksum_calculation="when_required",
            response_checksum_validation="when_required",
        ),
    )

    paginator = client.get_paginator("list_objects_v2")
    deleted = 0
    for page in paginator.paginate(Bucket=bucket):
        objects = [{"Key": item["Key"]} for item in page.get("Contents", [])]
        if not objects:
            continue
        client.delete_objects(Bucket=bucket, Delete={"Objects": objects})
        deleted += len(objects)

    print(f"Deleted {deleted} objects from s3://{bucket}")


if __name__ == "__main__":
    main()
