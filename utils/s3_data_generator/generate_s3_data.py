#!/usr/bin/env python3

from __future__ import annotations

import argparse
import random
import shutil
import string
import sys
from dataclasses import dataclass
from pathlib import Path


SIZE_UNITS = {
    "b": 1,
    "kb": 1_000,
    "mb": 1_000_000,
    "gb": 1_000_000_000,
    "tb": 1_000_000_000_000,
    "kib": 1024,
    "mib": 1024**2,
    "gib": 1024**3,
    "tib": 1024**4,
}

CHUNK_SIZE = 1024 * 1024


@dataclass(frozen=True)
class FileTask:
    relative_path: Path
    size: int
    ordinal: int


def parse_size(value: str) -> int:
    raw = value.strip().lower()
    if not raw:
        raise argparse.ArgumentTypeError("size cannot be empty")

    number = ""
    unit = ""
    for char in raw:
        if char.isdigit() or char == ".":
            if unit:
                raise argparse.ArgumentTypeError(f"invalid size: {value}")
            number += char
        else:
            unit += char

    if not number:
        raise argparse.ArgumentTypeError(f"invalid size: {value}")

    unit = unit or "b"
    if unit not in SIZE_UNITS:
        valid_units = ", ".join(sorted(SIZE_UNITS))
        raise argparse.ArgumentTypeError(f"invalid size unit '{unit}'. Valid units: {valid_units}")

    size = int(float(number) * SIZE_UNITS[unit])
    if size < 1:
        raise argparse.ArgumentTypeError("size must be greater than zero")
    return size


def format_size(size: int) -> str:
    for unit, multiplier in (("TiB", 1024**4), ("GiB", 1024**3), ("MiB", 1024**2), ("KiB", 1024)):
        if size >= multiplier:
            return f"{size / multiplier:.2f} {unit}"
    return f"{size} B"


def random_name(rng: random.Random, length: int = 8) -> str:
    alphabet = string.ascii_lowercase + string.digits
    return "".join(rng.choice(alphabet) for _ in range(length))


def build_folder_pool(
    rng: random.Random,
    prefix: str,
    min_folders: int,
    max_folders: int,
    max_depth: int,
) -> list[Path]:
    folder_count = rng.randint(min_folders, max_folders)
    folders: list[Path] = []
    clean_prefix = prefix.strip("/")

    for _ in range(folder_count):
        depth = rng.randint(1, max_depth)
        parts = [random_name(rng) for _ in range(depth)]
        if clean_prefix:
            parts.insert(0, clean_prefix)
        folders.append(Path(*parts))

    return folders


def build_file_plan(
    total_size: int,
    min_file_size: int,
    max_file_size: int,
    folders: list[Path],
    rng: random.Random,
) -> list[FileTask]:
    remaining = total_size
    tasks: list[FileTask] = []

    while remaining > 0:
        upper_bound = min(max_file_size, remaining)
        lower_bound = min(min_file_size, upper_bound)
        size = rng.randint(lower_bound, upper_bound)
        folder = rng.choice(folders)
        extension = rng.choice(("bin", "dat", "log", "json", "txt"))
        ordinal = len(tasks) + 1
        filename = f"file-{ordinal:08d}-{random_name(rng, 6)}.{extension}"
        tasks.append(FileTask(relative_path=folder / filename, size=size, ordinal=ordinal))
        remaining -= size

    return tasks


def validate_output_dir(path: Path, force: bool) -> None:
    if path.exists() and not path.is_dir():
        raise ValueError(f"output path exists and is not a directory: {path}")
    if path.exists() and any(path.iterdir()) and not force:
        raise ValueError(f"output directory is not empty: {path}. Use --force to allow writing into it.")


def write_file(path: Path, size: int, seed: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    rng = random.Random(seed)
    remaining = size

    with path.open("wb") as file:
        while remaining > 0:
            chunk_size = min(CHUNK_SIZE, remaining)
            file.write(rng.randbytes(chunk_size))
            remaining -= chunk_size


def create_files(output_dir: Path, tasks: list[FileTask], seed: int | None) -> None:
    total = len(tasks)
    total_bytes = sum(task.size for task in tasks)
    written_bytes = 0

    for task in tasks:
        target = output_dir / task.relative_path
        write_file(target, task.size, f"{seed or 0}:{task.ordinal}:{task.relative_path}:{task.size}")
        written_bytes += task.size
        if task.ordinal == total or task.ordinal % max(1, min(25, total // 20 or 1)) == 0:
            percent = written_bytes / total_bytes * 100
            print(
                f"Created {task.ordinal}/{total} files, {format_size(written_bytes)}/{format_size(total_bytes)} "
                f"({percent:.1f}%)",
                flush=True,
            )


def print_upload_examples(output_dir: Path, bucket: str, endpoint: str, prefix: str) -> None:
    host = endpoint.removeprefix("https://").removeprefix("http://").rstrip("/")
    source = output_dir.resolve()
    target_prefix = prefix.strip("/")
    s3_target = f"s3://{bucket}/"
    rclone_target = f":s3:{bucket}/"

    print("\nUpload with s3cmd:")
    print(f"s3cmd sync {source}/ {s3_target} \\")
    print('  --access_key="$LINODE_ACCESS_KEY" \\')
    print('  --secret_key="$LINODE_SECRET_KEY" \\')
    print(f"  --host={host} \\")
    print(f"  --host-bucket='%(bucket)s.{host}'")

    print("\nDry-run upload with s3cmd:")
    print(f"s3cmd sync --dry-run {source}/ {s3_target} \\")
    print('  --access_key="$LINODE_ACCESS_KEY" \\')
    print('  --secret_key="$LINODE_SECRET_KEY" \\')
    print(f"  --host={host} \\")
    print(f"  --host-bucket='%(bucket)s.{host}'")

    print("\nUpload with rclone:")
    print(f"rclone copy {source}/ {rclone_target} \\")
    print("  --s3-provider Other \\")
    print('  --s3-access-key-id "$LINODE_ACCESS_KEY" \\')
    print('  --s3-secret-access-key "$LINODE_SECRET_KEY" \\')
    print(f"  --s3-endpoint https://{host} \\")
    print("  --progress")

    if target_prefix:
        print("\nCleanup generated objects with s3cmd:")
        print(f"s3cmd del --recursive --force s3://{bucket}/{target_prefix}/ \\")
        print('  --access_key="$LINODE_ACCESS_KEY" \\')
        print('  --secret_key="$LINODE_SECRET_KEY" \\')
        print(f"  --host={host} \\")
        print(f"  --host-bucket='%(bucket)s.{host}'")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate randomized local files for S3-compatible upload tests.")
    parser.add_argument("--total-size", required=True, type=parse_size, help="Total data to generate, e.g. 10GiB.")
    parser.add_argument("--output-dir", required=True, type=Path, help="Local directory where files are generated.")
    parser.add_argument("--prefix", default="generated-data", help="Top-level folder prefix under output-dir.")
    parser.add_argument("--min-file-size", type=parse_size, default=parse_size("64KiB"))
    parser.add_argument("--max-file-size", type=parse_size, default=parse_size("64MiB"))
    parser.add_argument("--max-depth", type=int, default=4, help="Maximum folder depth below prefix.")
    parser.add_argument("--min-folders", type=int, default=3, help="Minimum generated folder count.")
    parser.add_argument("--max-folders", type=int, default=30, help="Maximum generated folder count.")
    parser.add_argument("--seed", type=int, help="Seed for repeatable file names, sizes, and contents.")
    parser.add_argument("--dry-run", action="store_true", help="Print the file plan without creating files.")
    parser.add_argument("--force", action="store_true", help="Allow writing into an existing non-empty output directory.")
    parser.add_argument("--print-upload-command", action="store_true", help="Print s3cmd and rclone upload command templates.")
    parser.add_argument("--bucket", default="my-bucket", help="Bucket name used only for printed upload examples.")
    parser.add_argument(
        "--endpoint-url",
        default="https://us-east-1.linodeobjects.com",
        help="S3 endpoint URL used only for printed upload examples.",
    )
    return parser.parse_args()


def validate_args(args: argparse.Namespace) -> None:
    if args.min_file_size > args.max_file_size:
        raise ValueError("--min-file-size cannot be greater than --max-file-size")
    if args.max_depth < 1:
        raise ValueError("--max-depth must be at least 1")
    if args.min_folders < 1:
        raise ValueError("--min-folders must be at least 1")
    if args.max_folders < args.min_folders:
        raise ValueError("--max-folders cannot be less than --min-folders")


def main() -> int:
    args = parse_args()

    try:
        validate_args(args)
        validate_output_dir(args.output_dir, args.force or args.dry_run)
    except ValueError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1

    rng = random.Random(args.seed)
    folders = build_folder_pool(rng, args.prefix, args.min_folders, args.max_folders, args.max_depth)
    tasks = build_file_plan(args.total_size, args.min_file_size, args.max_file_size, folders, rng)

    print("Local S3 data generation plan")
    print(f"Output directory: {args.output_dir}")
    print(f"Total size: {format_size(args.total_size)}")
    print(f"Files: {len(tasks)}")
    print(f"Folders: {len(folders)}")
    print(f"Prefix: {args.prefix.strip('/') or '(none)'}")

    if args.dry_run:
        print("\nDry run file sample:")
        for task in tasks[:20]:
            print(f"  {task.relative_path} ({format_size(task.size)})")
        if len(tasks) > 20:
            print(f"  ... {len(tasks) - 20} more files")
    else:
        args.output_dir.mkdir(parents=True, exist_ok=True)
        create_files(args.output_dir, tasks, args.seed)
        usage = shutil.disk_usage(args.output_dir)
        print("\nGeneration complete")
        print(f"Created files: {len(tasks)}")
        print(f"Created bytes: {format_size(sum(task.size for task in tasks))}")
        print(f"Available disk after generation: {format_size(usage.free)}")

    if args.print_upload_command:
        print_upload_examples(args.output_dir, args.bucket, args.endpoint_url, args.prefix)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
