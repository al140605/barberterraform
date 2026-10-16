output "environment" {
  description = "Nombre del ambiente efimero (el workspace de Terraform)."
  value       = local.environment
}

output "ecr_repository_url" {
  description = "URL del repositorio ECR del ambiente."
  value       = aws_ecr_repository.ephemeral.repository_url
}

output "log_group_name" {
  description = "Grupo de logs del ambiente."
  value       = aws_cloudwatch_log_group.ephemeral.name
}

output "ecs_cluster_name" {
  description = "Clúster ECS del ambiente (sin servicios ni tareas)."
  value       = aws_ecs_cluster.ephemeral.name
}

output "security_group_id" {
  description = "Grupo de seguridad del ambiente (sin reglas de entrada); null si create_security_group = false."
  value       = one(aws_security_group.ephemeral[*].id)
}
