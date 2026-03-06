variable "aws_region" {
  description = "The AWS region to deploy resources"
  type        = string
  default     = "us-east-2"
}

variable "stream_name" {
  description = "The name of the Kinesis data stream"
  type        = string
  default     = "terraform-kinesis-poc"
}

variable "shard_count" {
  description = "The number of shards that the stream uses (1 shard = 1 MB/s write, 2 MB/s read)"
  type        = number
  default     = 1
}

variable "retention_period" {
  description = "The number of hours for data records to remain accessible after being added (24-8760)"
  type        = number
  default     = 24
}
