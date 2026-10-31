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

# Despliegue por OIDC desde GitHub Actions (oidc_despliegue.tf). No son secretos: nombres e IDs publicos de repositorio.
variable "github_deploy_sub_prefixes" {
  description = <<-EOT
    Prefijo del subject OIDC de cada repositorio cuyos jobs del entorno de despliegue pueden asumir el rol. Estos repos usan
    el subject inmutable de GitHub, que lleva los IDs numericos: repo:<propietario>@<id>/<repo>@<id>. Se leen con
    `gh api repos/<propietario>/<repo>/actions/oidc/customization/sub` (campo sub_claim_prefix). El formato inmutable evita
    que un repositorio borrado y recreado con el mismo nombre herede el acceso.
  EOT
  type        = list(string)
  default = [
    "repo:KikeGonRam@170197719/barber@1171371659",
    "repo:KikeGonRam@170197719/frontend_Urbanblade@1358453475",
  ]

  validation {
    condition     = length(var.github_deploy_sub_prefixes) > 0 && alltrue([for prefix in var.github_deploy_sub_prefixes : can(regex("^repo:[A-Za-z0-9_.-]+@[0-9]+/[A-Za-z0-9_.-]+@[0-9]+$", prefix))])
    error_message = "Cada prefijo debe tener el formato repo:<propietario>@<id>/<repo>@<id>, sin comodines."
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
