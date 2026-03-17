output "application_name" {
  value       = aws_kinesisanalyticsv2_application.flink.name
  description = "Name of the Managed Flink application"
}

output "application_arn" {
  value       = aws_kinesisanalyticsv2_application.flink.arn
  description = "ARN of the Managed Flink application"
}

output "input_stream_name" {
  value       = aws_kinesis_stream.input.name
  description = "Name of the input Kinesis stream (feed records here)"
}

output "output_stream_name" {
  value       = aws_kinesis_stream.output.name
  description = "Name of the output Kinesis stream (enriched records appear here)"
}

output "s3_bucket_name" {
  value       = aws_s3_bucket.flink_jars.id
  description = "S3 bucket holding the Flink JAR (managed by aws_s3_object)"
}

output "jar_s3_key" {
  value       = var.jar_s3_key
  description = "Expected S3 key for the Flink JAR"
}

# Flink Web UI — AWS Console deep links
output "flink_jobmanager_ui_url" {
  value       = "https://${var.aws_region}.console.aws.amazon.com/managed-flink/home?region=${var.aws_region}#/applications/${aws_kinesisanalyticsv2_application.flink.name}/dashboard"
  description = "AWS Console URL for the Flink JobManager Web UI — open after the application reaches RUNNING status"
}

output "flink_taskmanager_ui_url" {
  value       = "https://${var.aws_region}.console.aws.amazon.com/managed-flink/home?region=${var.aws_region}#/applications/${aws_kinesisanalyticsv2_application.flink.name}/taskmanagers"
  description = "AWS Console URL for the Flink TaskManagers UI — open after the application reaches RUNNING status"
}
