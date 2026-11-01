locals {
  ecr_repositories = toset([
    "urbanblade/barber",
    "urbanblade/frontend-urban"
  ])

  log_groups = toset([
    "/ecs/urbanblade-staging/barber",
    "/ecs/urbanblade-staging/frontend-urban"
  ])
}

resource "aws_ecr_repository" "application" {
  for_each = local.ecr_repositories

  name = each.value

  # MUTABLE porque el despliegue actual empuja siempre la etiqueta `latest` y las definiciones de tarea de ECS la
  # usan. Pasar a IMMUTABLE solo despues de publicar con etiqueta unica (SHA) y de actualizar las definiciones de
  # tarea y el flujo de reversion; de lo contrario el siguiente `docker push` falla.
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  # Excepciones de checkov, justificadas:
  # - CKV_AWS_51: etiquetas mutables a proposito (ver comentario de image_tag_mutability).
  # - CKV_AWS_136: cambiar el cifrado de un repositorio ECR existente obliga a recrearlo (y perder las imagenes);
  #   hoy cifra con AES256 y el recurso tiene prevent_destroy. Revisar solo al crear repositorios nuevos.
  #checkov:skip=CKV_AWS_51:El despliegue de staging empuja `latest`; pasar a IMMUTABLE tras publicar con SHA.
  #checkov:skip=CKV_AWS_136:Cambiar a KMS recrea el repositorio ECR existente; hoy cifra con AES256.

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_cloudwatch_log_group" "application" {
  for_each = local.log_groups

  name = each.value

  # 90 dias para staging (decision del equipo, 2026-10-16); produccion debe retener mas.
  retention_in_days = 90

  # Excepciones de checkov, justificadas:
  # - CKV_AWS_338: pide 1 año; en staging se acordaron 90 dias.
  # - CKV_AWS_158: cifrar con KMS exige crear una llave y permisos para ECS/CloudWatch; pendiente.
  #checkov:skip=CKV_AWS_338:Staging retiene 90 dias; produccion debe retener al menos 1 año.
  #checkov:skip=CKV_AWS_158:Requiere crear llave KMS y permisos; pendiente de incorporar con ECS.

  lifecycle {
    prevent_destroy = true
  }
}

import {
  to = aws_ecr_repository.application["urbanblade/barber"]
  id = "urbanblade/barber"
}

import {
  to = aws_ecr_repository.application["urbanblade/frontend-urban"]
  id = "urbanblade/frontend-urban"
}

import {
  to = aws_cloudwatch_log_group.application["/ecs/urbanblade-staging/barber"]
  id = "/ecs/urbanblade-staging/barber"
}

import {
  to = aws_cloudwatch_log_group.application["/ecs/urbanblade-staging/frontend-urban"]
  id = "/ecs/urbanblade-staging/frontend-urban"
}
