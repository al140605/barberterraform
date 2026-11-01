# T024 - Red de staging.
# La VPC predeterminada y sus subredes NO se administran aqui (no se crean ni se destruyen): solo se leen.
# Los grupos de seguridad existentes se IMPORTAN tal cual estan en AWS; el primer plan no debe reemplazarlos.

data "aws_vpc" "default" {
  default = true
}

# Subredes por las que hoy sale el ALB y corren las tareas (las predeterminadas de esas dos zonas).
data "aws_subnet" "staging" {
  for_each = toset(["us-east-1d", "us-east-1f"])

  vpc_id            = data.aws_vpc.default.id
  availability_zone = each.value
  default_for_az    = true
}

# Rangos de origen de CloudFront administrados por AWS.
data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

locals {
  # Un grupo de seguridad por puerto del ALB, abierto solo a CloudFront.
  alb_cloudfront_ports = toset(["80", "8080"])

  # Puertos de las aplicaciones (barber 80, frontend 3000) que el grupo de las tareas acepta del ALB.
  task_ports = toset([80, 3000])
}

resource "aws_security_group" "alb_cloudfront" {
  for_each = local.alb_cloudfront_ports

  # name y description no se pueden cambiar en un grupo existente (obligaria a reemplazarlo): deben coincidir con AWS.
  name        = "uba-stg-alb-cf-${each.value}"
  description = "ALB staging: solo CloudFront puerto ${each.value}"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port       = tonumber(each.value)
    to_port         = tonumber(each.value)
    protocol        = "tcp"
    prefix_list_ids = [data.aws_ec2_managed_prefix_list.cloudfront.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #checkov:skip=CKV_AWS_382:El ALB necesita salida para llegar a las tareas; sin NAT ni VPC endpoints no se acota mas.
  #checkov:skip=CKV_AWS_23:Reglas existentes sin descripcion; agregarla modifica las reglas en AWS (cambio aparte).
  #checkov:skip=CKV2_AWS_5:Esta en uso: el ALB lo asocia en alb.tf con una expresion for que checkov no resuelve.

  lifecycle {
    prevent_destroy = true
  }
}

# Grupo heredado del ALB anterior. Ya no esta asociado al balanceador, pero el grupo de las tareas lo sigue
# nombrando en sus reglas de entrada. Se importa tal cual para no alterarlo; retirarlo es una decision aparte.
resource "aws_security_group" "alb_legacy" {
  name        = "urbanblade-staging-alb-sg"
  description = "UrbanBlade staging ALB"
  vpc_id      = data.aws_vpc.default.id

  dynamic "ingress" {
    for_each = toset([80, 8080])

    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #checkov:skip=CKV_AWS_260:Grupo existente, sin interfaces de red asociadas; se importa sin cambios. Retirarlo exige quitar su referencia del grupo de las tareas (pendiente).
  #checkov:skip=CKV_AWS_382:Grupo existente y sin uso; se importa sin cambios.
  #checkov:skip=CKV2_AWS_5:Grupo existente y sin uso; se importa sin cambios (pendiente de retirar).
  #checkov:skip=CKV_AWS_23:Reglas existentes sin descripcion; agregarla modifica las reglas en AWS (cambio aparte).

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_security_group" "tasks" {
  name        = "urbanblade-staging-tasks-sg"
  description = "UrbanBlade staging tasks (ALB only)"
  vpc_id      = data.aws_vpc.default.id

  dynamic "ingress" {
    for_each = local.task_ports

    content {
      from_port = ingress.value
      to_port   = ingress.value
      protocol  = "tcp"
      security_groups = [
        aws_security_group.alb_legacy.id,
        aws_security_group.alb_cloudfront["80"].id
      ]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #checkov:skip=CKV_AWS_382:Las tareas Fargate necesitan salida a ECR, MongoDB Atlas, Stripe y otros servicios; sin NAT ni VPC endpoints no se acota mas.
  #checkov:skip=CKV_AWS_23:Reglas existentes sin descripcion; agregarla modifica las reglas en AWS (cambio aparte).
  #checkov:skip=CKV2_AWS_5:Las tareas de ECS lo usan; los servicios se codifican en T026 y checkov aun no ve esa asociacion.

  lifecycle {
    prevent_destroy = true
  }
}

import {
  for_each = {
    "80"   = "sg-0a537dcb25fcf51b2"
    "8080" = "sg-0372b1aa878f1657f"
  }

  to = aws_security_group.alb_cloudfront[each.key]
  id = each.value
}

import {
  to = aws_security_group.alb_legacy
  id = "sg-0dbd32344bd423d23"
}

import {
  to = aws_security_group.tasks
  id = "sg-0d01fa3c3044c3832"
}
