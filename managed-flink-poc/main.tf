terraform {
  required_version = ">= 1.0.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# S3 — stores the Flink application JAR
resource "aws_s3_bucket" "flink_jars" {
  bucket        = var.s3_bucket_name
  force_destroy = true

  tags = {
    Name        = var.s3_bucket_name
    Environment = "poc"
  }
}

resource "aws_s3_bucket_versioning" "flink_jars" {
  bucket = aws_s3_bucket.flink_jars.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Kinesis — input and output streams
resource "aws_kinesis_stream" "input" {
  name             = "${var.app_name}-input"
  shard_count      = 1
  retention_period = 24

  stream_mode_details {
    stream_mode = "PROVISIONED"
  }

  tags = {
    Name        = "${var.app_name}-input"
    Environment = "poc"
  }
}

resource "aws_kinesis_stream" "output" {
  name             = "${var.app_name}-output"
  shard_count      = 1
  retention_period = 24

  stream_mode_details {
    stream_mode = "PROVISIONED"
  }

  tags = {
    Name        = "${var.app_name}-output"
    Environment = "poc"
  }
}

# IAM — execution role for the Flink application
resource "aws_iam_role" "flink" {
  name = "${var.app_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "kinesisanalytics.amazonaws.com" }
    }]
  })

  tags = {
    Name        = "${var.app_name}-role"
    Environment = "poc"
  }
}

resource "aws_iam_role_policy" "flink" {
  name = "${var.app_name}-policy"
  role = aws_iam_role.flink.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "KinesisRead"
        Effect = "Allow"
        Action = [
          "kinesis:GetShardIterator",
          "kinesis:GetRecords",
          "kinesis:DescribeStream",
          "kinesis:DescribeStreamSummary",
          "kinesis:ListShards",
          "kinesis:SubscribeToShard",
        ]
        Resource = aws_kinesis_stream.input.arn
      },
      {
        Sid    = "KinesisWrite"
        Effect = "Allow"
        Action = [
          "kinesis:PutRecord",
          "kinesis:PutRecords",
          "kinesis:DescribeStream",
          "kinesis:DescribeStreamSummary",
          "kinesis:ListShards",
        ]
        Resource = aws_kinesis_stream.output.arn
      },
      {
        Sid    = "S3GetJar"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
        ]
        Resource = "${aws_s3_bucket.flink_jars.arn}/*"
      },
      {
        Sid    = "S3ListBucket"
        Effect = "Allow"
        Action = ["s3:ListBucket"]
        Resource = aws_s3_bucket.flink_jars.arn
      },
      {
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Sid      = "CloudWatchMetrics"
        Effect   = "Allow"
        Action   = ["cloudwatch:PutMetricData"]
        Resource = "*"
      },
    ]
  })
}

# CloudWatch — log group and stream for Flink application logs
resource "aws_cloudwatch_log_group" "flink" {
  name              = "/aws/managed-flink/${var.app_name}"
  retention_in_days = 7

  tags = {
    Name        = "${var.app_name}-logs"
    Environment = "poc"
  }
}

resource "aws_cloudwatch_log_stream" "flink" {
  name           = "flink-app"
  log_group_name = aws_cloudwatch_log_group.flink.name
}

# Upload the pre-built Flink JAR to S3
# Run the Docker build command from README Step 1 before terraform apply.
resource "aws_s3_object" "flink_jar" {
  bucket = aws_s3_bucket.flink_jars.id
  key    = var.jar_s3_key
  source = "${path.module}/flink-job/target/flink-sensor-job-1.0.jar"
  etag   = filemd5("${path.module}/flink-job/target/flink-sensor-job-1.0.jar")

  depends_on = [aws_s3_bucket_versioning.flink_jars]
}

# Managed Flink application
resource "aws_kinesisanalyticsv2_application" "flink" {
  depends_on = [aws_s3_object.flink_jar]

  name                   = var.app_name
  runtime_environment    = "FLINK-1_18"
  service_execution_role = aws_iam_role.flink.arn

  application_configuration {
    application_code_configuration {
      code_content {
        s3_content_location {
          bucket_arn = aws_s3_bucket.flink_jars.arn
          file_key   = var.jar_s3_key
        }
      }

      # JAR files are ZIP archives
      code_content_type = "ZIPFILE"
    }

    flink_application_configuration {
      checkpoint_configuration {
        # Use Flink defaults: checkpointing disabled, exactly-once
        configuration_type = "DEFAULT"
      }

      monitoring_configuration {
        configuration_type = "CUSTOM"
        log_level          = "INFO"
        metrics_level      = "APPLICATION"
      }

      parallelism_configuration {
        configuration_type   = "CUSTOM"
        auto_scaling_enabled = false
        parallelism          = 1   # 1 KPU = 1 vCPU, 4 GB RAM
        parallelism_per_kpu  = 1
      }
    }

    # Key/value properties read inside the job via KinesisAnalyticsRuntime
    environment_properties {
      property_group {
        property_group_id = "FlinkApplicationProperties"
        property_map = {
          "input.stream.arn"   = aws_kinesis_stream.input.arn
          "output.stream.name" = aws_kinesis_stream.output.name
          "aws.region"         = var.aws_region
        }
      }
    }
  }

  cloudwatch_logging_options {
    log_stream_arn = aws_cloudwatch_log_stream.flink.arn
  }

  tags = {
    Name        = var.app_name
    Environment = "poc"
  }
}
