#!/usr/bin/env python3
# /// script
# dependencies = ["boto3>=1.34", "huggingface_hub>=0.23", "tqdm>=4.66"]
# ///
from __future__ import annotations

import argparse
import os
from pathlib import Path

import boto3
from botocore.config import Config
from boto3.s3.transfer import TransferConfig
from huggingface_hub import hf_hub_download
from tqdm import tqdm

QUOTE_TRANSLATION = str.maketrans(
    {
        "\u201c": '"',
        "\u201d": '"',
        "\u2018": "'",
        "\u2019": "'",
    }
)


class Progress:
    def __init__(self, path: Path) -> None:
        self._bar = tqdm(total=path.stat().st_size, unit="B", unit_scale=True, desc="upload")

    def __call__(self, bytes_amount: int) -> None:
        self._bar.update(bytes_amount)

    def close(self) -> None:
        self._bar.close()


def env(name: str, default: str | None = None) -> str:
    value = os.environ.get(name, default)
    if not value:
        raise SystemExit(f"Missing required environment variable: {name}")
    return value.strip().translate(QUOTE_TRANSLATION).strip("'\"")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Download a Hugging Face model file and upload it to Linode Object Storage.")
    parser.add_argument("--repo", default=os.environ.get("HF_MODEL_REPO", "bartowski/Qwen2.5-14B-Instruct-GGUF"))
    parser.add_argument("--filename", default=os.environ.get("HF_MODEL_FILE", "Qwen2.5-14B-Instruct-Q4_K_M.gguf"))
    parser.add_argument("--object-key", default=os.environ.get("MODEL_OBJECT_KEY", "models/qwen2.5-14b-instruct-q4_k_m.gguf"))
    parser.add_argument("--cache-dir", default=os.environ.get("MODEL_CACHE_DIR", ".model-cache"))
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    bucket = env("LINODE_BUCKET")
    endpoint = env("LINODE_ENDPOINT")
    access_key = env("LINODE_ACCESS_KEY")
    secret_key = env("LINODE_SECRET_KEY")
    token = env("HF_TOKEN")

    cache_dir = Path(args.cache_dir)
    cache_dir.mkdir(parents=True, exist_ok=True)

    print(f"Downloading hf://{args.repo}/{args.filename}")
    model_path = Path(
        hf_hub_download(
            repo_id=args.repo,
            filename=args.filename,
            token=token,
            local_dir=cache_dir,
        )
    )

    size_gib = model_path.stat().st_size / (1024**3)
    print(f"Uploading {model_path} ({size_gib:.2f} GiB) to s3://{bucket}/{args.object_key}")
    client = boto3.client(
        "s3",
        endpoint_url=endpoint,
        aws_access_key_id=access_key,
        aws_secret_access_key=secret_key,
        config=Config(
            signature_version="s3v4",
            s3={"addressing_style": "path"},
            request_checksum_calculation="when_required",
            response_checksum_validation="when_required",
        ),
    )

    progress = Progress(model_path)
    try:
        client.upload_file(
            str(model_path),
            bucket,
            args.object_key,
            Callback=progress,
            Config=TransferConfig(multipart_threshold=5 * 1024**3),
        )
    finally:
        progress.close()

    head = client.head_object(Bucket=bucket, Key=args.object_key)
    print(f"Uploaded object size: {head['ContentLength']} bytes")


if __name__ == "__main__":
    main()
