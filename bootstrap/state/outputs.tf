output "state_bucket_name" {
  description = "Nombre del bucket S3 para el backend remoto."
  value       = aws_s3_bucket.terraform_state.id
}

output "state_bucket_region" {
  description = "Region del bucket S3 para el backend remoto."
  value       = var.aws_region
}