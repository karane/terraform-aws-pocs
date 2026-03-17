# kinesis-poc

AWS Kinesis Data Streams — provisioning a stream with Terraform and producing/consuming messages with Python.

## Pre-requisites

- Terraform >= 1.0
- Python 3.8+
- AWS credentials exported:

```bash
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_DEFAULT_REGION=us-east-2
```

## Deployment

```bash
terraform init
terraform apply
```

Note the stream name from the output:

```bash
terraform output stream_name
```

## Install Python dependencies

```bash
cd scripts
pip install -r requirements.txt
```

## Producing messages

Send a batch of messages to the stream:

```bash
python scripts/producer.py
```

Or override the stream name and message count:

```bash
python scripts/producer.py --stream terraform-kinesis-poc --count 20
```

Each message is a JSON record with a timestamp, sequence number, and random sensor reading.

## Consuming messages

Poll the stream from the beginning (`TRIM_HORIZON`):

```bash
python scripts/consumer.py
```

Or start from the latest position only (useful for live tailing):

```bash
python scripts/consumer.py --iterator-type LATEST
```

Override the stream name:

```bash
python scripts/consumer.py --stream terraform-kinesis-poc
```

Press `Ctrl+C` to stop the consumer.

## Useful AWS CLI commands

Describe the stream:

```bash
aws kinesis describe-stream-summary --stream-name terraform-kinesis-poc
```

List shards:

```bash
aws kinesis list-shards --stream-name terraform-kinesis-poc
```

Get a shard iterator and manually fetch records:

```bash
SHARD_ID=$(aws kinesis list-shards \
  --stream-name terraform-kinesis-poc \
  --query "Shards[0].ShardId" --output text)

ITERATOR=$(aws kinesis get-shard-iterator \
  --stream-name terraform-kinesis-poc \
  --shard-id "$SHARD_ID" \
  --shard-iterator-type TRIM_HORIZON \
  --query "ShardIterator" --output text)

aws kinesis get-records --shard-iterator "$ITERATOR" --limit 10
```

## Shard capacity

Scale shards with: `terraform apply -var="shard_count=2"`

## Clean up

```bash
terraform destroy
```
