output "cluster_name" {
  value       = aws_eks_cluster.main.name
  description = "Name of the EKS cluster"
}

output "cluster_arn" {
  value       = aws_eks_cluster.main.arn
  description = "ARN of the EKS cluster"
}

output "cluster_endpoint" {
  value       = aws_eks_cluster.main.endpoint
  description = "API server endpoint of the EKS cluster"
}

output "cluster_version" {
  value       = aws_eks_cluster.main.version
  description = "Kubernetes version running on the cluster"
}

output "cluster_certificate_authority" {
  value       = aws_eks_cluster.main.certificate_authority[0].data
  description = "Base64-encoded certificate authority data for the cluster"
}

output "node_group_arn" {
  value       = aws_eks_node_group.main.arn
  description = "ARN of the managed node group"
}

output "node_group_status" {
  value       = aws_eks_node_group.main.status
  description = "Status of the managed node group"
}

output "kubeconfig_command" {
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.main.name}"
  description = "Run this command to configure kubectl for this cluster"
}
