"""
Enriched Records Consumer — Managed Flink POC

Usage:
    python consumer.py
    python consumer.py --stream terraform-flink-poc-output --region us-east-2
    python consumer.py --iterator-type LATEST
"""

import argparse
import base64
import json
import signal
import sys
import time

import boto3
from botocore.exceptions import ClientError

DEFAULT_STREAM = "terraform-flink-poc-output"
DEFAULT_REGION = "us-east-2"
POLL_INTERVAL_S = 1.0


def get_shards(client, stream_name: str) -> list:
    paginator = client.get_paginator("list_shards")
    shards = []
    for page in paginator.paginate(StreamName=stream_name):
        shards.extend(page["Shards"])
    return shards


def get_shard_iterators(client, stream_name: str, shards: list, iterator_type: str) -> dict:
    iterators = {}
    for shard in shards:
        shard_id = shard["ShardId"]
        response = client.get_shard_iterator(
            StreamName=stream_name,
            ShardId=shard_id,
            ShardIteratorType=iterator_type,
        )
        iterators[shard_id] = response["ShardIterator"]
    return iterators


def poll_shards(client, iterators: dict, total: list) -> dict:
    next_iterators = {}

    for shard_id, iterator in iterators.items():
        if iterator is None:
            continue

        try:
            response = client.get_records(ShardIterator=iterator, Limit=100)
        except ClientError as e:
            code = e.response["Error"]["Code"]
            if code == "ExpiredIteratorException":
                print(f"  [WARN] Iterator expired for {shard_id} — shard skipped.")
                next_iterators[shard_id] = None
                continue
            raise

        for record in response.get("Records", []):
            raw = record["Data"]
            try:
                payload = json.loads(raw)
            except json.JSONDecodeError:
                payload = base64.b64encode(raw).decode()

            total[0] += 1
            seq = record["SequenceNumber"][:20] + "..."

            temp_c = payload.get("temperature_c", "?")
            temp_f = payload.get("temperature_f", "NOT SET")
            processed = payload.get("processed_by", "NOT SET")

            print(
                f"  [{total[0]:>4}] {payload.get('sensor_id', '?')}  "
                f"temp={temp_c}°C → {temp_f}°F  "
                f"processed_by={processed}  "
                f"seq={seq}"
            )

        next_iterators[shard_id] = response.get("NextShardIterator")

    return next_iterators


def main() -> None:
    parser = argparse.ArgumentParser(description="Managed Flink POC — consumer")
    parser.add_argument("--stream", default=DEFAULT_STREAM, help="Output Kinesis stream name")
    parser.add_argument(
        "--iterator-type",
        default="TRIM_HORIZON",
        choices=["TRIM_HORIZON", "LATEST"],
        help="Shard iterator type (default: TRIM_HORIZON)",
    )
    parser.add_argument("--region", default=DEFAULT_REGION, help="AWS region")
    args = parser.parse_args()

    client = boto3.client("kinesis", region_name=args.region)

    print(f"Connecting to output stream '{args.stream}' in {args.region} ...")
    shards = get_shards(client, args.stream)
    
    print(f"Found {len(shards)} shard(s): {[s['ShardId'] for s in shards]}")
    print(f"Iterator type: {args.iterator_type}")
    print("Waiting for Flink-enriched records... (Ctrl+C to stop)\n")
    print(f"  {'#':>4}  sensor       temp (C→F)          processed_by  seq")
    print("  " + "-" * 70)

    iterators = get_shard_iterators(client, args.stream, shards, args.iterator_type)
    total = [0]

    def handle_sigint(sig, frame):
        print(f"\nStopped. Total enriched records consumed: {total[0]}")
        sys.exit(0)

    signal.signal(signal.SIGINT, handle_sigint)

    while True:
        iterators = poll_shards(client, iterators, total)

        if all(v is None for v in iterators.values()):
            print("All shards exhausted.")
            break

        time.sleep(POLL_INTERVAL_S)

    print(f"Total enriched records consumed: {total[0]}")


if __name__ == "__main__":
    main()
