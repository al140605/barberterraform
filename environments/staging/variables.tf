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

# Control de costos (costos.tf). Los correos no se versionan: se pasan al aplicar.
variable "budget_alert_emails" {
  description = "Correos que reciben los avisos del presupuesto mensual. Vacio = no se crea el presupuesto."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for email in var.budget_alert_emails : can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", email))])
    error_message = "Cada correo debe tener un formato valido (usuario@dominio)."
  }
}

# Alarmas de disponibilidad (alarmas.tf). Los correos no se versionan: se pasan al aplicar.
variable "alarm_alert_emails" {
  description = "Correos que reciben las alarmas de disponibilidad de staging (por SNS). Vacio = no se crea nada. Cada direccion debe confirmar la suscripcion desde el correo que envia AWS."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for email in var.alarm_alert_emails : can(regex("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$", email))])
    error_message = "Cada correo debe tener un formato valido (usuario@dominio)."
  }
}

variable "budget_limit_usd" {
  description = "Limite del presupuesto mensual en USD, con impuestos y sin restar creditos. Se calcula con el gasto estimado de un mes completo mas margen."
  type        = number
  default     = 120

  validation {
    condition     = var.budget_limit_usd > 0
    error_message = "El limite del presupuesto debe ser mayor que cero."
  }
}

variable "autoscaling_min_tasks" {
  description = "Tareas minimas de frontend y barber (autoescalado)."
  type        = number
  default     = 1

  validation {
    condition     = var.autoscaling_min_tasks >= 1
    error_message = "El minimo debe ser al menos 1 tarea."
  }
}

variable "autoscaling_max_tasks" {
  description = "Tareas maximas de frontend y barber (autoescalado). Cada tarea extra cuesta unos 22 USD al mes sin IVA si se mantiene encendida."
  type        = number
  default     = 2

  validation {
    condition     = var.autoscaling_max_tasks >= var.autoscaling_min_tasks
    error_message = "El maximo no puede ser menor que el minimo."
  }
}

variable "atlas_region" {
  description = "Region de Atlas del clúster, en el formato de Atlas (por ejemplo US_EAST_1). Debe coincidir con la real."
  type        = string
  default     = "US_EAST_1"
}
