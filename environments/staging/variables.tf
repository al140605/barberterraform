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

# T118 - Datos de MongoDB Atlas que no estan en ningun archivo del repo. Se ven en Atlas (Project Settings y la pagina
# del clúster); no son secretos, pero tampoco se versionan: van en terraform.tfvars, que Git ignora.
variable "atlas_project_id" {
  description = "ID del proyecto de Atlas (24 caracteres hexadecimales; Project Settings)."
  type        = string

  validation {
    condition     = can(regex("^[0-9a-f]{24}$", var.atlas_project_id))
    error_message = "El ID del proyecto de Atlas son 24 caracteres hexadecimales."
  }
}

variable "atlas_cluster_name" {
  description = "Nombre del clúster de Atlas de staging."
  type        = string
}

variable "atlas_region" {
  description = "Region de Atlas del clúster, en el formato de Atlas (por ejemplo US_EAST_1). Debe coincidir con la real."
  type        = string
  default     = "US_EAST_1"
}
