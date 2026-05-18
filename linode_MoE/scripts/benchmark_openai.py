#!/usr/bin/env python3

import argparse
import json
import statistics
import time
from concurrent.futures import ThreadPoolExecutor, as_completed

import requests


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Simple local benchmark for vLLM OpenAI API.")
    parser.add_argument("--url", default="http://127.0.0.1:8000/v1/chat/completions")
    parser.add_argument("--model", required=True)
    parser.add_argument("--concurrency", type=int, required=True)
    parser.add_argument("--requests", type=int, required=True)
    parser.add_argument("--max-tokens", type=int, default=256)
    parser.add_argument("--timeout", type=int, default=180)
    parser.add_argument("--output", required=True)
    return parser.parse_args()


def make_payload(model: str, max_tokens: int) -> dict:
    return {
        "model": model,
        "messages": [
            {
                "role": "user",
                "content": "Explain in 3 concise bullet points why expert parallelism helps MoE throughput.",
            }
        ],
        "temperature": 0.0,
        "max_tokens": max_tokens,
    }


def send_request(session: requests.Session, url: str, payload: dict, timeout: int) -> dict:
    started = time.time()
    try:
        response = session.post(url, json=payload, timeout=timeout)
        latency = time.time() - started
        response.raise_for_status()
        body = response.json()
        usage = body.get("usage", {})
        completion_tokens = int(usage.get("completion_tokens", 0))
        prompt_tokens = int(usage.get("prompt_tokens", 0))
        return {
            "ok": True,
            "latency_s": latency,
            "completion_tokens": completion_tokens,
            "prompt_tokens": prompt_tokens,
        }
    except Exception as exc:  # noqa: BLE001
        latency = time.time() - started
        return {
            "ok": False,
            "latency_s": latency,
            "completion_tokens": 0,
            "prompt_tokens": 0,
            "error": str(exc),
        }


def percentile(values: list[float], p: float) -> float:
    if not values:
        return 0.0
    idx = max(0, min(len(values) - 1, int(round((p / 100.0) * (len(values) - 1)))))
    ordered = sorted(values)
    return ordered[idx]


def main() -> None:
    args = parse_args()
    payload = make_payload(args.model, args.max_tokens)

    results = []
    started = time.time()
    with requests.Session() as session:
        with ThreadPoolExecutor(max_workers=args.concurrency) as executor:
            futures = [
                executor.submit(send_request, session, args.url, payload, args.timeout)
                for _ in range(args.requests)
            ]
            for fut in as_completed(futures):
                results.append(fut.result())
    elapsed = max(1e-6, time.time() - started)

    successes = [r for r in results if r["ok"]]
    failures = [r for r in results if not r["ok"]]

    total_completion_tokens = sum(r["completion_tokens"] for r in successes)
    total_prompt_tokens = sum(r["prompt_tokens"] for r in successes)

    latencies = [r["latency_s"] for r in successes]
    p50 = percentile(latencies, 50)
    p95 = percentile(latencies, 95)
    avg_latency = statistics.mean(latencies) if latencies else 0.0

    summary = {
        "timestamp": int(time.time()),
        "target_url": args.url,
        "model": args.model,
        "concurrency": args.concurrency,
        "requests": args.requests,
        "success": len(successes),
        "failed": len(failures),
        "success_rate": len(successes) / max(1, len(results)),
        "wall_time_seconds": elapsed,
        "completion_tokens": total_completion_tokens,
        "prompt_tokens": total_prompt_tokens,
        "completion_tokens_per_second": total_completion_tokens / elapsed,
        "p50_latency_seconds": p50,
        "p95_latency_seconds": p95,
        "avg_latency_seconds": avg_latency,
        "sample_errors": [f.get("error", "") for f in failures[:5]],
    }

    with open(args.output, "w", encoding="utf-8") as f:
        json.dump(summary, f, indent=2)

    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
