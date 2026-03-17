variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-2"
}

variable "app_name" {
  description = "Name of the Managed Flink application (also used as a prefix for all resources)"
  type        = string
  default     = "terraform-flink-poc"
}

variable "s3_bucket_name" {
  description = "S3 bucket to store the Flink application JAR"
  type        = string
  default     = "terraform-flink-poc-jars"
}

variable "jar_s3_key" {
  description = "S3 object key for the uploaded Flink JAR"
  type        = string
  default     = "flink-job/flink-sensor-job-1.0.jar"
}
