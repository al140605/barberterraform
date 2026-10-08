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