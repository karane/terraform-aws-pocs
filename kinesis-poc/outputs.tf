output "stream_name" {
  value       = aws_kinesis_stream.example.name
  description = "The name of the Kinesis data stream"
}

output "stream_arn" {
  value       = aws_kinesis_stream.example.arn
  description = "The ARN of the Kinesis data stream"
}

output "stream_shard_count" {
  value       = aws_kinesis_stream.example.shard_count
  description = "The number of shards in the Kinesis data stream"
}
