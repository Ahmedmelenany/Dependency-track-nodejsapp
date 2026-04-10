output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "rds_endpoint" {
  description = "RDS PostgreSQL endpoint"
  value       = aws_db_instance.postgres.endpoint
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = aws_ecs_cluster.main.name
}

output "ecr_apiserver_url" {
  description = "ECR repository URL for the API server"
  value       = aws_ecr_repository.apiserver.repository_url
}

output "ecr_frontend_url" {
  description = "ECR repository URL for the frontend"
  value       = aws_ecr_repository.frontend.repository_url
}

output "efs_id" {
  description = "EFS file system ID"
  value       = aws_efs_file_system.dtrack.id
}
