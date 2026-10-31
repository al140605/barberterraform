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

# Despliegue por OIDC desde GitHub Actions (oidc_despliegue.tf). No son secretos: nombres de repositorio y de entorno.
variable "github_deploy_repositories" {
  description = "Repositorios de GitHub (propietario/nombre) cuyos jobs del entorno de despliegue pueden asumir el rol."
  type        = list(string)
  default     = ["KikeGonRam/barber", "KikeGonRam/frontend_Urbanblade"]

  validation {
    condition     = length(var.github_deploy_repositories) > 0 && alltrue([for repo in var.github_deploy_repositories : can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", repo))])
    error_message = "Cada repositorio debe tener el formato propietario/nombre, sin comodines."
  }
}

variable "github_deploy_environment" {
  description = "Entorno de GitHub que autoriza el despliegue (el token OIDC lo incluye en su sub)."
  type        = string
  default     = "staging"
}

variable "github_oidc_provider_arn" {
  description = "ARN del proveedor OIDC de GitHub si ya existe en la cuenta (solo puede haber uno); null lo crea."
  type        = string
  default     = null
}

variable "atlas_region" {
  description = "Region de Atlas del clúster, en el formato de Atlas (por ejemplo US_EAST_1). Debe coincidir con la real."
  type        = string
  default     = "US_EAST_1"
}
