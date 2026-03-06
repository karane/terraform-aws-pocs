"""
Kinesis Consumer POC

Iterator types:
  TRIM_HORIZON  — start from the oldest available record (default)
  LATEST        — start from the next record written after this consumer starts

Usage:
    python consumer.py
    python consumer.py --stream my-stream --iterator-type LATEST --region us-east-2
"""

import argparse
import base64
import json
import signal
import sys
import time

import boto3
from botocore.exceptions import ClientError

DEFAULT_STREAM = "terraform-kinesis-poc"
DEFAULT_REGION = "us-east-2"
POLL_INTERVAL_IN_SECS = 1.0


def get_shards(client, stream_name: str) -> list[str]:
    paginator = client.get_paginator("list_shards")
    shards = []
    for page in paginator.paginate(StreamName=stream_name):
        shards.extend(page["Shards"])
    return shards


def get_shard_iterators(client, stream_name: str, shards: list, iterator_type: str) -> dict[str, str]:
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


def poll_shards(client, iterators: dict[str, str], total: list) -> dict[str, str]:
    """Fetch one batch of records from every shard and return updated iterators."""
    next_iterators = {}

    for shard_id, iterator in iterators.items():
        if iterator is None:
            continue  # shard reached its end (closed)

        try:
            response = client.get_records(ShardIterator=iterator, Limit=100)
        except ClientError as e:
            code = e.response["Error"]["Code"]
            if code == "ExpiredIteratorException":
                print(f"  [WARN] Iterator expired for {shard_id} — shard will be skipped.")
                next_iterators[shard_id] = None
                continue
            raise

        records = response.get("Records", [])
        for record in records:
            raw = record["Data"]
            try:
                payload = json.loads(raw)
            except json.JSONDecodeError:
                # Fall back to showing raw base64 if data isn't JSON
                payload = base64.b64encode(raw).decode()

            total[0] += 1
            seq = record["SequenceNumber"][:20] + "..."
            print(
                f"  [{total[0]:>4}] shard={shard_id}  seq={seq}  data={json.dumps(payload)}"
            )

        next_iterators[shard_id] = response.get("NextShardIterator")

    return next_iterators


def main() -> None:
    parser = argparse.ArgumentParser(description="Kinesis consumer POC")
    parser.add_argument("--stream", default=DEFAULT_STREAM, help="Kinesis stream name")
    parser.add_argument(
        "--iterator-type",
        default="TRIM_HORIZON",
        # check all options later
        choices=["TRIM_HORIZON", "LATEST", "AT_SEQUENCE_NUMBER", "AFTER_SEQUENCE_NUMBER"],
        help="Shard iterator type (default: TRIM_HORIZON)",
    )
    parser.add_argument("--region", default=DEFAULT_REGION, help="AWS region")
    args = parser.parse_args()

    client = boto3.client("kinesis", region_name=args.region)

    print(f"Connecting to stream '{args.stream}' in {args.region} ...")
    shards = get_shards(client, args.stream)
    print(f"Found {len(shards)} shard(s): {[s['ShardId'] for s in shards]}")
    print(f"Iterator type: {args.iterator_type}")
    print("Press Ctrl+C to stop.\n")

    iterators = get_shard_iterators(client, args.stream, shards, args.iterator_type)
    total = [0]  

    def handle_sigint(sig, frame):
        print(f"\nStopped. Total records consumed: {total[0]}")
        sys.exit(0)

    signal.signal(signal.SIGINT, handle_sigint)

    while True:
        iterators = poll_shards(client, iterators, total)

        # All shards exhausted
        if all(v is None for v in iterators.values()):
            print("All shards exhausted.")
            break

        time.sleep(POLL_INTERVAL_IN_SECS)

    print(f"Total records consumed: {total[0]}")


if __name__ == "__main__":
    main()
