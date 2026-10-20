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

variable "create_security_group" {
  description = "Crea tambien un grupo de seguridad de prueba. Requiere el permiso ec2:CreateTags (default_tags etiqueta el grupo); el usuario staging-deploy no lo tiene hoy, por eso es false por defecto."
  type        = bool
  default     = false
}

variable "aws_account_id" {
  description = "Cuenta AWS esperada; protege contra credenciales apuntando a otra cuenta."
  type        = string
}
