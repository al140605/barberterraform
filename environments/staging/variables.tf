variable "project_name" {
  description = "Nombre comun usado en etiquetas de recursos."
  type        = string
  default     = "urbanblade"
}

variable "environment" {
  description = "Ambiente aislado por esta configuracion raiz."
  type        = string
  default     = "staging"
}

variable "aws_region" {
  description = "Region AWS donde vive el staging actual."
  type        = string
  default     = "us-east-1"
}

variable "aws_account_id" {
  description = "Cuenta AWS esperada; protege contra credenciales apuntando a otra cuenta."
  type        = string
}

variable "atlas_public_key" {
  description = "API public key del proveedor MongoDB Atlas, inyectada por entorno."
  type        = string
  sensitive   = true
}

variable "atlas_private_key" {
  description = "API private key del proveedor MongoDB Atlas, inyectada por entorno."
  type        = string
  sensitive   = true
}