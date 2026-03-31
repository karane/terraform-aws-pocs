output "ecs_cluster_name" {
  value = aws_ecs_cluster.flask.name
}

output "ecs_service_name" {
  value = aws_ecs_service.flask.name
}

output "ecr_repository_url" {
  value = aws_ecr_repository.flask.repository_url
}

output "instance_type" {
  value = var.instance_type
}
