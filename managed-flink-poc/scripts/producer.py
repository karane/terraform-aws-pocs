"""
Sensor Producer — Managed Flink POC

Usage:
    python producer.py
    python producer.py --stream terraform-flink-poc-input --count 20 --region us-east-2
"""

import argparse
import json
import random
import time
from datetime import datetime, timezone

import boto3
from botocore.exceptions import ClientError

DEFAULT_STREAM = "terraform-flink-poc-input"
DEFAULT_REGION = "us-east-2"
DEFAULT_COUNT = 10


def build_record(sequence: int) -> dict:
    return {
        "sequence": sequence,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "sensor_id": f"sensor-{random.randint(1, 5):02d}",
        "temperature_c": round(random.uniform(18.0, 35.0), 2),
        "humidity_pct": round(random.uniform(30.0, 90.0), 2),
    }


def send_records(client, stream_name: str, count: int) -> None:
    print(f"Sending {count} records to '{stream_name}' (Flink input stream) ...\n")

    for i in range(1, count + 1):
        record = build_record(sequence=i)
        data = json.dumps(record)
        partition_key = record["sensor_id"]

        try:
            response = client.put_record(
                StreamName=stream_name,
                Data=data.encode("utf-8"),
                PartitionKey=partition_key,
            )
            shard_id = response["ShardId"]
            seq = response["SequenceNumber"][:20] + "..."
            print(
                f"  [{i:>3}] {record['sensor_id']}  "
                f"temp={record['temperature_c']}°C  "
                f"hum={record['humidity_pct']}%  "
                f"shard={shard_id}  seq={seq}"
            )
        except ClientError as e:
            print(f"  [{i:>3}] ERROR: {e.response['Error']['Message']}")

        time.sleep(0.05)

    print(f"\nDone. {count} records sent to the input stream.")
    print("The Flink job will enrich them and write to the output stream.")


def main() -> None:
    parser = argparse.ArgumentParser(description="Managed Flink POC — producer")
    parser.add_argument("--stream", default=DEFAULT_STREAM, help="Input Kinesis stream name")
    parser.add_argument("--count", type=int, default=DEFAULT_COUNT, help="Number of records to send")
    parser.add_argument("--region", default=DEFAULT_REGION, help="AWS region")
    args = parser.parse_args()

    client = boto3.client("kinesis", region_name=args.region)
    send_records(client, stream_name=args.stream, count=args.count)


if __name__ == "__main__":
    main()
