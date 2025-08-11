terraform {
  required_version = ">= 1.0.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }

  backend "s3" {

    # This backend configuration is filled in automatically at test time by Terratest. If you wish to run this example
    # manually, uncomment and fill in the config below.

    bucket         = "karane-terraform-state-poc-bucket-20250811-220732-77eb7e"
    key            = "global/s3/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "karane-terraform-state-poc-table-20250811-220732-77eb7e"
    encrypt        = true

  }
}

provider "aws" {
  region = "us-east-2"
}

resource "aws_db_instance" "example" {
  identifier_prefix   = "terraform-up-and-running"
  engine              = "mysql"
  allocated_storage   = 10
  instance_class      = "db.t3.micro"
  skip_final_snapshot = true

  db_name             = var.db_name

  username = var.db_username
  password = var.db_password
}