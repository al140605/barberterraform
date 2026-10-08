variable "aws_region" {
  description = "Region donde se aloja el bucket remoto de estado."
  type        = string
  default     = "us-east-1"
}

variable "aws_account_id" {
  description = "Cuenta esperada; el bootstrap falla si las credenciales apuntan a otra."
  type        = string
}

variable "state_bucket_name" {
  description = "Nombre globalmente unico del bucket dedicado al estado Terraform."
  type        = string
  default     = "urbanblade-terraform-state-209479293733"
}