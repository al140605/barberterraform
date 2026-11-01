# Higiene de las imagenes en ECR: limpieza automatica y escaneo de vulnerabilidades al subir.
#
# Contexto: cada despliegue vuelve a subir `latest`, y la imagen anterior queda sin etiqueta; ademas el pipeline deja una
# etiqueta `rollback-<fecha>-pre-<sha>` por despliegue. Sin una politica, nada de eso se borra (a 31-oct-2026: 211 y 235
# imagenes, casi 100 GB, tres cuartas partes sin etiqueta). Las definiciones de tarea usan la etiqueta `latest`, asi que una
# imagen sin etiqueta no la necesita ninguna tarea; la reversion usa las etiquetas `rollback-*`, que se conservan.
#
# Como oidc_despliegue.tf, este archivo no depende de los recursos importados de ECR: los repositorios se nombran por cadena
# y se puede planear y aplicar con -target sin arrastrar la adopcion del resto de staging al estado.

locals {
  # Solo los repositorios que publica el pipeline de despliegue.
  ecr_lifecycle_repositories = ["urbanblade/barber", "urbanblade/frontend-urban"]

  # ECR evalua las reglas por prioridad. Ninguna regla toca `latest` ni las etiquetas ajenas (por ejemplo las de despliegues
  # manuales anteriores): solo expiran las imagenes sin etiqueta y las sha-* o rollback-* que ya pasaron del limite.
  ecr_lifecycle_policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Imagenes sin etiqueta con mas de 14 dias (las `latest` que ya fueron reemplazadas)"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 14
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 2
        description  = "Conservar las 20 imagenes sha-<commit> mas recientes"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["sha-"]
          countType     = "imageCountMoreThan"
          countNumber   = 20
        }
        action = { type = "expire" }
      },
      {
        rulePriority = 3
        description  = "Conservar las 10 imagenes de reversion rollback-* mas recientes"
        selection = {
          tagStatus     = "tagged"
          tagPrefixList = ["rollback-"]
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = { type = "expire" }
      },
    ]
  })
}

resource "aws_ecr_lifecycle_policy" "deploy" {
  for_each = toset(local.ecr_lifecycle_repositories)

  repository = each.value
  policy     = local.ecr_lifecycle_policy
}

# Escaneo basico (gratuito) de cada imagen al subirla. Es una configuracion de la cuenta y la region, no de un repositorio:
# aplica a todos los repositorios de ECR. Hoy el registro esta en BASIC sin reglas (escaneo manual).
# Los workflows de despliegue muestran el resumen de vulnerabilidades en el resumen de cada ejecucion; es informativo y no
# bloquea el despliegue.
resource "aws_ecr_registry_scanning_configuration" "basic_on_push" {
  scan_type = "BASIC"

  rule {
    scan_frequency = "SCAN_ON_PUSH"

    repository_filter {
      filter      = "*"
      filter_type = "WILDCARD"
    }
  }
}
