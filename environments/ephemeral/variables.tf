variable "project_name" {
  description = "Nombre comun usado en etiquetas de recursos."
  type        = string
  default     = "urbanblade"
}

variable "aws_region" {
  description = "Region AWS donde se crea el ambiente efimero."
  type        = string
  default     = "us-east-1"
}

variable "aws_account_id" {
  description = "Cuenta AWS esperada; protege contra credenciales apuntando a otra cuenta."
  type        = string
}
