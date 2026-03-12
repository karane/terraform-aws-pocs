output "ecr_repository_url" {
  description = "The ECR repository URL (used by build_and_push.sh)"
  value       = aws_ecr_repository.flask.repository_url
}

output "cluster_name" {
  description = "The name of the ECS cluster"
  value       = aws_ecs_cluster.example.name
}

output "service_name" {
  description = "The name of the ECS service"
  value       = aws_ecs_service.example.name
}

# NOTE: Fargate task public IPs are assigned at runtime to the task's ENI and
# are not available as native Terraform resource attributes. Use the AWS CLI
# commands in the README to retrieve the public IP after apply.
