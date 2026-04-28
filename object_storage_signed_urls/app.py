import os
import sqlite3
import threading
import time
from urllib.error import HTTPError, URLError
from urllib.parse import parse_qs, urlparse
from urllib.request import urlopen

import boto3
from botocore.client import Config
from flask import Flask, Response, jsonify, request


def get_required_env(name: str) -> str:
    value = os.getenv(name)
    if not value:
        raise RuntimeError(f"Missing required environment variable: {name}")
    return value


def build_s3_client():
    endpoint = get_required_env("LINODE_S3_ENDPOINT")
    if not endpoint.startswith("http://") and not endpoint.startswith("https://"):
        endpoint = f"https://{endpoint}"

    return boto3.client(
        "s3",
        region_name=get_required_env("LINODE_REGION"),
        aws_access_key_id=get_required_env("LINODE_ACCESS_KEY"),
        aws_secret_access_key=get_required_env("LINODE_SECRET_KEY"),
        endpoint_url=endpoint,
        config=Config(signature_version="s3v4"),
    )


app = Flask(__name__)

BUCKET = get_required_env("LINODE_BUCKET")
DEFAULT_EXPIRATION = int(os.getenv("SIGNED_URL_EXPIRATION", "900"))
S3_CLIENT = build_s3_client()

DB_PATH = os.path.join(os.path.dirname(__file__), "signed_urls.db")


def init_db() -> None:
    with sqlite3.connect(DB_PATH) as conn:
        conn.execute("""
            CREATE TABLE IF NOT EXISTS signed_urls (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                type TEXT NOT NULL,
                key TEXT NOT NULL,
                bucket TEXT NOT NULL,
                signed_url TEXT NOT NULL,
                expires_at INTEGER NOT NULL,
                created_at INTEGER NOT NULL
            )
        """)


def store_signed_url(url_type: str, key: str, bucket: str, signed_url: str, expires_in: int) -> None:
    now = int(time.time())
    with sqlite3.connect(DB_PATH) as conn:
        conn.execute(
            "INSERT INTO signed_urls (type, key, bucket, signed_url, expires_at, created_at) VALUES (?,?,?,?,?,?)",
            (url_type, key, bucket, signed_url, now + expires_in, now),
        )


def cleanup_expired() -> None:
    grace_cutoff = int(time.time()) - 300  # 5-minute grace period
    with sqlite3.connect(DB_PATH) as conn:
        conn.execute("DELETE FROM signed_urls WHERE expires_at < ?", (grace_cutoff,))


def cleanup_loop() -> None:
    while True:
        time.sleep(60)
        cleanup_expired()


def parse_key(payload: dict) -> str:
    key = payload.get("key", "").strip()
    if not key:
        raise ValueError("'key' is required")
    return key


def parse_expires(payload: dict) -> int:
    raw = payload.get("expires_in", DEFAULT_EXPIRATION)
    expires = int(raw)
    if expires < 1 or expires > 604800:
        raise ValueError("'expires_in' must be between 1 and 604800 seconds")
    return expires


@app.get("/health")
def health():
    return jsonify({"status": "ok", "bucket": BUCKET})


@app.post("/api/signed-url/upload")
def create_upload_signed_url():
    payload = request.get_json(silent=True) or {}

    try:
        key = parse_key(payload)
        expires_in = parse_expires(payload)
    except (ValueError, TypeError) as exc:
        return jsonify({"error": str(exc)}), 400

    params = {"Bucket": BUCKET, "Key": key}
    content_type = (payload.get("content_type") or "").strip()
    if content_type:
        params["ContentType"] = content_type

    signed_url = S3_CLIENT.generate_presigned_url(
        "put_object",
        Params=params,
        ExpiresIn=expires_in,
        HttpMethod="PUT",
    )

    store_signed_url("upload", key, BUCKET, signed_url, expires_in)
    return jsonify(
        {
            "method": "PUT",
            "bucket": BUCKET,
            "key": key,
            "expires_in": expires_in,
            "content_type": content_type or None,
            "signed_url": signed_url,
        }
    )


@app.post("/api/signed-url/read")
def create_read_signed_url():
    payload = request.get_json(silent=True) or {}

    try:
        key = parse_key(payload)
        expires_in = parse_expires(payload)
    except (ValueError, TypeError) as exc:
        return jsonify({"error": str(exc)}), 400

    signed_url = S3_CLIENT.generate_presigned_url(
        "get_object",
        Params={"Bucket": BUCKET, "Key": key},
        ExpiresIn=expires_in,
        HttpMethod="GET",
    )

    store_signed_url("read", key, BUCKET, signed_url, expires_in)
    return jsonify(
        {
            "method": "GET",
            "bucket": BUCKET,
            "key": key,
            "expires_in": expires_in,
            "signed_url": signed_url,
        }
    )


def infer_filename(signed_url: str) -> str:
    parsed = urlparse(signed_url)
    query = parse_qs(parsed.query)

    if "Key" in query and query["Key"]:
        key = query["Key"][0]
        if key.strip():
            return key.rsplit("/", 1)[-1]

    path = parsed.path.rsplit("/", 1)[-1]
    return path or "downloaded-file"


@app.post("/api/download")
def download_using_signed_url():
    payload = request.get_json(silent=True) or {}
    signed_url = (payload.get("signed_url") or "").strip()
    if not signed_url:
        return jsonify({"error": "'signed_url' is required"}), 400

    filename = (payload.get("filename") or "").strip() or infer_filename(signed_url)

    try:
        with urlopen(signed_url, timeout=60) as upstream:
            data = upstream.read()
            content_type = upstream.headers.get("Content-Type", "application/octet-stream")
    except HTTPError as exc:
        return jsonify({"error": f"Signed URL request failed with status {exc.code}"}), 400
    except URLError as exc:
        return jsonify({"error": f"Unable to reach signed URL: {exc.reason}"}), 400

    response = Response(data, mimetype=content_type)
    response.headers["Content-Disposition"] = f'attachment; filename="{filename}"'
    return response


@app.get("/api/signed-urls")
def list_signed_urls():
    active_only = request.args.get("active", "").lower() == "true"
    now = int(time.time())
    with sqlite3.connect(DB_PATH) as conn:
        conn.row_factory = sqlite3.Row
        if active_only:
            rows = conn.execute(
                "SELECT * FROM signed_urls WHERE expires_at > ? ORDER BY created_at DESC", (now,)
            ).fetchall()
        else:
            rows = conn.execute("SELECT * FROM signed_urls ORDER BY created_at DESC").fetchall()
    return jsonify([dict(r) for r in rows])


if __name__ == "__main__":
    port = int(os.getenv("FLASK_PORT", "5000"))
    init_db()
    threading.Thread(target=cleanup_loop, daemon=True).start()
    app.run(host="0.0.0.0", port=port)
