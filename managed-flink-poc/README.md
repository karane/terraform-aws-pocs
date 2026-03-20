# Managed Flink POC

Demonstrates AWS Managed Service for Apache Flink — provisioning the application with Terraform, submitting a Java Flink job, and verifying enriched output with Python.

## Concepts covered

| Resource / Concept | What it demonstrates |
|--------------------|----------------------|
| `aws_kinesisanalyticsv2_application` | Managed Flink app with FLINK-1_18 runtime |
| `FLINK-1_18` runtime | Apache Flink 1.18 on fully managed infrastructure |
| `KinesisStreamsSource` | Read from a Kinesis stream using the new FLIP-27 source API |
| `KinesisStreamsSink` | Write to a Kinesis stream using the async sink API |
| `KinesisAnalyticsRuntime` | Read per-app properties injected by AWS at runtime |
| `environment_properties` | Pass stream ARN/name to the job without hardcoding |
| `parallelism_configuration` | Control KPU count and parallelism |
| `checkpoint_configuration` | Enable fault-tolerant state checkpointing |
| Maven shade plugin | Build a fat JAR bundling all non-provided dependencies |

## Pre-requisites

- Terraform >= 1.0
- Docker
- Python 3.8+
- AWS credentials exported:

```bash
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_DEFAULT_REGION=us-east-2
```

## Step 1 — Build the JAR

Terraform uploads the JAR as an `aws_s3_object`, so it must exist locally before `terraform apply`.

```bash
bash scripts/build.sh
```

This produces `flink-job/target/flink-sensor-job-1.0.jar`.

## Step 2 — Provision infrastructure

```bash
cd managed-flink-poc
terraform init
terraform apply
```

## Step 3 — Start the Flink application

```bash
aws kinesisanalyticsv2 start-application \
  --application-name terraform-flink-poc \
  --run-configuration '{"FlinkRunConfiguration":{"AllowNonRestoredState":true}}'
```

Wait ~30-60 seconds for the status to reach `RUNNING`:

```bash
aws kinesisanalyticsv2 describe-application \
  --application-name terraform-flink-poc \
  --query "ApplicationDetail.ApplicationStatus"
```

Once running, print the Flink Web UI links:

```bash
terraform output flink_jobmanager_ui_url
terraform output flink_taskmanager_ui_url
```

Open either URL in a browser — the AWS Console proxies the Flink dashboard (no public DNS is exposed for Managed Flink).

## Step 4 — Install Python dependencies

```bash
cd scripts
pip install -r requirements.txt
```

## Step 5 — Send records to the input stream

```bash
python scripts/producer.py
```

Or override defaults:

```bash
python scripts/producer.py --stream terraform-flink-poc-input --count 20
```

## Step 6 — Consume enriched records from the output stream

```bash
python scripts/consumer.py
```

Start from the latest position only:

```bash
python scripts/consumer.py --iterator-type LATEST
```

## Redeploying JAR updates

After the initial `terraform apply`, use the script to rebuild and redeploy the JAR without touching Terraform. The script stops the application, uploads the new JAR, and restarts it automatically.

```bash
bash scripts/build_and_upload.sh
```

## Flink Web UI (JobManager & TaskManager)

The Apache Flink dashboard is proxied through the AWS Console — Managed Flink does not expose a public DNS endpoint for the JobManager or TaskManager. The application must be in `RUNNING` state before the dashboard is accessible.

Terraform outputs the direct deep-link URLs after `apply`:

```bash
terraform output flink_jobmanager_ui_url   # JobManager overview, job DAG, checkpoints
terraform output flink_taskmanager_ui_url  # TaskManager list, metrics, logs, thread dumps
```

### Open the dashboard

**Via Terraform output (recommended):**

```bash
xdg-open $(terraform output -raw flink_jobmanager_ui_url)   # Linux
open $(terraform output -raw flink_jobmanager_ui_url)        # macOS
```

**Or via the AWS Console manually:**

```
AWS Console
  → Amazon Managed Service for Apache Flink
    → Applications
      → terraform-flink-poc
        → [button] Open Apache Flink dashboard
```

This opens the standard Flink Web UI in a new tab.

### JobManager UI

The **Overview** tab shows the running job:

| Field | What to look for |
|-------|-----------------|
| Status | `RUNNING` |
| Tasks | Total / Running / Finished / Failed counts |
| Checkpoints | Last completed checkpoint time and duration |
| Uptime | How long the job has been running |

Click the job name → **Timeline** to see the operator DAG:

```
Kinesis Input Stream  →  Enrich: C→F + tag  →  Kinesis Sink
        (Source)               (Map)            (Async Sink)
```

The **Checkpoints** tab shows:
- Whether checkpointing is enabled
- Latest completed checkpoint size and duration
- Any failed checkpoints and the reason

### TaskManager UI

Click **Task Managers** in the left sidebar to list all TaskManagers (this POC has 1).

Select a TaskManager to see:

| Tab | What it shows |
|-----|---------------|
| **Metrics** | JVM heap/GC, CPU load, network buffers |
| **Log** | Raw TaskManager log output (stdout/stderr from your job) |
| **Stdout** | Anything written to `System.out` in the job code |
| **Thread Dump** | Live thread snapshot — useful for diagnosing hangs |

### View logs per subtask

From the job DAG, click an operator → **SubTasks** tab → click the log icon next to any subtask to open its TaskManager log filtered to that subtask's output.

### Get the dashboard URL via CLI

The Console proxies the dashboard via a signed URL. To retrieve it:

```bash
aws kinesisanalyticsv2 describe-application \
  --application-name terraform-flink-poc \
  --include-additional-details \
  --query "ApplicationDetail.ApplicationConfigurationDescription"
```

The direct dashboard link is only available in the Console UI — the CLI does not return a browsable URL. Alternatively, tail logs from the CLI:

```bash
# All Flink application logs (JobManager + TaskManager mixed)
aws logs tail /aws/managed-flink/terraform-flink-poc --follow

# Filter to errors only
aws logs tail /aws/managed-flink/terraform-flink-poc \
  --follow \
  --filter-pattern "ERROR"
```

## Useful AWS CLI commands

Check application status:

```bash
aws kinesisanalyticsv2 describe-application \
  --application-name terraform-flink-poc \
  --query "ApplicationDetail.ApplicationStatus"
```

List all Managed Flink applications:

```bash
aws kinesisanalyticsv2 list-applications
```

Tail Flink logs from CloudWatch:

```bash
aws logs tail /aws/managed-flink/terraform-flink-poc --follow
```

Stop the application (saves a snapshot by default):

```bash
aws kinesisanalyticsv2 stop-application \
  --application-name terraform-flink-poc
```

## KPU and cost

Each Kinesis Processing Unit (KPU) = 1 vCPU + 4 GB RAM.
This POC runs with `parallelism = 1` → 1 KPU.

| Pricing element | Detail |
|-----------------|--------|
| KPU-hours | ~$0.11/KPU-hour (us-east) |
| Storage | $0.023/GB-month (for checkpoints/snapshots in S3) |
| Kinesis streams | ~$0.015/shard-hour |

**Stop or destroy when not in use.**

## Clean up

Stop the application first, then destroy all resources:

```bash
aws kinesisanalyticsv2 stop-application --application-name terraform-flink-poc
terraform destroy
```
