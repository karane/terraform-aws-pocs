variable "bucket_name" {
  description = "The name of the S3 bucket. Must be globally unique."
  type        = string
  default     = "karane-terraform-state-poc-bucket-20250811-220732-77eb7e"
}

variable "table_name" {
  description = "The name of the DynamoDB table. Must be unique in this AWS account."
  type        = string
  default = "karane-terraform-state-poc-table-20250811-220732-77eb7e"
}