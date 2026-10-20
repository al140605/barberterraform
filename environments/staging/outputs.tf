output "aws_account_id" {
  description = "Cuenta AWS activa verificada por el proveedor."
  value       = data.aws_caller_identity.current.account_id
}

output "aws_region" {
  description = "Region configurada para el staging."
  value       = var.aws_region
}

output "environment" {
  description = "Ambiente de esta configuracion raiz."
  value       = var.environment
}

# T029 - Salidas de la infraestructura importada. Ninguna es sensible: son nombres, URLs publicas de ECR, IDs y ARN de
# recursos. Los valores de los secretos nunca se declaran en Terraform; solo se exponen sus nombres.

output "vpc_id" {
  description = "VPC predeterminada donde corre staging (solo se lee, no se administra)."
  value       = data.aws_vpc.default.id
}

output "subnet_ids" {
  description = "Subredes usadas por el ALB y las tareas, por zona de disponibilidad."
  value       = { for az, subnet in data.aws_subnet.staging : az => subnet.id }
}

output "ecr_repository_urls" {
  description = "URL de cada repositorio ECR administrado, por nombre."
  value       = { for name, repo in aws_ecr_repository.application : name => repo.repository_url }
}

output "log_group_names" {
  description = "Grupos de logs de CloudWatch administrados."
  value       = sort([for group in aws_cloudwatch_log_group.application : group.name])
}

output "security_group_ids" {
  description = "Grupos de seguridad importados: uno de CloudFront por puerto (alb_cloudfront_<puerto>), el de las tareas y el heredado."
  value = merge(
    { for port, group in aws_security_group.alb_cloudfront : "alb_cloudfront_${port}" => group.id },
    {
      tasks      = aws_security_group.tasks.id
      alb_legacy = aws_security_group.alb_legacy.id
    }
  )
}

output "alb_dns_name" {
  description = "Nombre DNS del ALB de staging (origen de las distribuciones de CloudFront)."
  value       = aws_lb.staging.dns_name
}

output "alb_arn" {
  description = "ARN del ALB de staging."
  value       = aws_lb.staging.arn
}

output "alb_listeners" {
  description = "Puerto de cada listener del ALB y el target group al que reenvia por defecto."
  value       = local.alb_listeners
}

output "target_group_arns" {
  description = "ARN de cada target group (barber, frontend, spark)."
  value       = { for name, group in aws_lb_target_group.staging : name => group.arn }
}

output "ecs_cluster_name" {
  description = "Clúster ECS de staging."
  value       = aws_ecs_cluster.staging.name
}

output "ecs_service_names" {
  description = "Servicios ECS administrados (barber y frontend)."
  value       = { for key, service in aws_ecs_service.staging : key => service.name }
}

output "barber_secret_names" {
  description = "Nombres de los secretos de barber en Secrets Manager (nunca sus valores)."
  value       = sort([for secret in aws_secretsmanager_secret.barber : secret.name])
}

# T120 - CloudFront y S3. Nombres y dominios publicos; nada sensible.
output "cloudfront_distributions" {
  description = "Distribuciones de CloudFront (frontend, api, spark): ID, dominio de CloudFront y alias propios."
  value = {
    for key, dist in aws_cloudfront_distribution.staging : key => {
      id      = dist.id
      domain  = dist.domain_name
      aliases = sort(tolist(dist.aliases))
    }
  }
}

output "s3_bucket_names" {
  description = "Buckets S3 de la plataforma (uploads publico de solo lectura y receipts privado)."
  value       = { for key, bucket in aws_s3_bucket.storage : key => bucket.id }
}

# T118 - Atlas. Solo nombres; las cadenas de conexion llevan credenciales y no se exponen.
output "atlas_cluster_name" {
  description = "Nombre del clúster de Atlas administrado."
  value       = mongodbatlas_advanced_cluster.staging.name
}

output "atlas_database_usernames" {
  description = "Usuarios de base de datos de Atlas administrados (sin contraseñas)."
  value       = sort([for user in mongodbatlas_database_user.staging : user.username])
}
