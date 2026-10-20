# T032 - Ambiente efimero de prueba (apply y destroy).
#
# Crea un ambiente desechable y diminuto (ECR, log group y clúster ECS sin tareas; opcionalmente un grupo de
# seguridad sin entrada) para comprobar el ciclo completo crear -> verificar -> destruir sin tocar staging.
#
# - El nombre del ambiente es el WORKSPACE de Terraform y debe empezar por `eph-`: ningun nombre de staging
#   (`urbanblade-staging`, `urbanblade/barber`, ...) puede coincidir con los de aqui.
# - Nada lleva `prevent_destroy` y el ECR usa `force_delete`: `terraform destroy` debe poder borrarlo todo.
# - No incluye ALB, NAT ni secretos (cuestan dinero o se retienen al borrarse).

data "aws_caller_identity" "current" {}

check "expected_aws_account" {
  assert {
    condition     = data.aws_caller_identity.current.account_id == var.aws_account_id
    error_message = "Las credenciales AWS activas no pertenecen a aws_account_id."
  }
}

# Guarda del nombre: todos los recursos dependen de ella (`depends_on`), asi que no se crea nada si el workspace no
# cumple (por ejemplo `default`). El nombre sale directo del workspace para que el plan muestre los nombres reales.
resource "terraform_data" "guard" {
  input = terraform.workspace

  lifecycle {
    precondition {
      condition     = can(regex("^eph-[a-z0-9][a-z0-9-]{1,18}$", terraform.workspace))
      error_message = "El workspace debe llamarse eph-<nombre> (minusculas, digitos y guiones, hasta 23 caracteres). Crea uno con: terraform workspace new eph-t032"
    }
  }
}

locals {
  environment = terraform.workspace
  prefix      = "${var.project_name}-${local.environment}"
}

data "aws_vpc" "default" {
  default = true
}

resource "aws_ecr_repository" "ephemeral" {
  name                 = "${var.project_name}-ephemeral/${local.environment}"
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true
  depends_on           = [terraform_data.guard]

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
  }
}

resource "aws_cloudwatch_log_group" "ephemeral" {
  name              = "/ecs/${local.prefix}/app"
  retention_in_days = 7
  depends_on        = [terraform_data.guard]

  #checkov:skip=CKV_AWS_338:Ambiente desechable: 7 dias bastan y se borra con el ambiente.
  #checkov:skip=CKV_AWS_158:Ambiente desechable; evita crear y retirar una llave KMS por prueba.
}

resource "aws_ecs_cluster" "ephemeral" {
  name       = local.prefix
  depends_on = [terraform_data.guard]

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_security_group" "ephemeral" {
  count = var.create_security_group ? 1 : 0

  name        = "${local.prefix}-tasks"
  description = "Ambiente efimero ${local.environment}: sin entrada"
  vpc_id      = data.aws_vpc.default.id
  depends_on  = [terraform_data.guard]

  egress {
    description = "HTTPS hacia servicios de AWS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  #checkov:skip=CKV2_AWS_5:Ambiente desechable: el grupo no se asocia a nada a proposito; solo prueba crear y destruir.
}
