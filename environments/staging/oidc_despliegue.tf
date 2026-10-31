# Despliegue desde GitHub Actions sin llaves de larga duracion: GitHub presenta un token OIDC firmado, AWS lo valida y
# entrega credenciales temporales de un rol de privilegio minimo. Reemplaza el despliegue manual desde un equipo personal.
#
# Alcance del rol (solo lo que hoy hace el procedimiento de despliegue):
#   - subir imagenes y etiquetas a los repositorios ECR de barber y frontend-urban;
#   - forzar un nuevo despliegue de los servicios uba-stg-barber y uba-stg-frontend y consultar su estado.
# No puede leer secretos, tocar IAM, S3, la red ni registrar definiciones de tarea. Solo lo puede asumir un job que corre
# en el entorno de GitHub `staging` de los repositorios listados (subject inmutable con IDs) (y ese entorno exige aprobacion del propietario).

locals {
  # Servicios que el pipeline de despliegue puede actualizar y repositorios ECR que puede escribir.
  deploy_services  = ["barber", "frontend"]
  deploy_ecr_repos = ["urbanblade/barber", "urbanblade/frontend-urban"]

  # ARN calculados por nombre y no por referencia a los recursos importados (ECR, ECS): asi este archivo se puede planear y
  # aplicar solo, sin arrastrar la adopcion del resto de staging al estado. Los nombres son los de ecs.tf y resources.tf.
  deploy_account_arn      = "arn:aws:%s:${var.aws_region}:${data.aws_caller_identity.current.account_id}"
  deploy_ecr_arns         = [for name in local.deploy_ecr_repos : "${format(local.deploy_account_arn, "ecr")}:repository/${name}"]
  deploy_ecs_cluster      = "${var.project_name}-${var.environment}"
  deploy_ecs_cluster_arn  = "${format(local.deploy_account_arn, "ecs")}:cluster/${local.deploy_ecs_cluster}"
  deploy_ecs_service_arns = [for key in local.deploy_services : "${format(local.deploy_account_arn, "ecs")}:service/${local.deploy_ecs_cluster}/uba-stg-${key}"]
  deploy_oidc_subject     = [for prefix in var.github_deploy_sub_prefixes : "${prefix}:environment:${var.github_deploy_environment}"]

  github_oidc_provider_arn = var.github_oidc_provider_arn != null ? var.github_oidc_provider_arn : aws_iam_openid_connect_provider.github[0].arn
}

# Un proveedor OIDC de GitHub es unico por cuenta. Si ya existe, pasar su ARN en github_oidc_provider_arn y no se crea otro.
resource "aws_iam_openid_connect_provider" "github" {
  count = var.github_oidc_provider_arn == null ? 1 : 0

  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  # AWS valida la cadena de certificados de GitHub con sus autoridades raiz; la huella ya no se usa para este proveedor.
}

data "aws_iam_policy_document" "github_deploy_trust" {
  statement {
    sid     = "GitHubActionsStaging"
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.github_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Solo jobs del entorno `staging` de los repositorios indicados; una rama, un fork o otro entorno no pueden asumirlo.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = local.deploy_oidc_subject
    }
  }
}

resource "aws_iam_role" "github_deploy" {
  name        = "${var.project_name}-${var.environment}-github-deploy"
  description = "Despliegue a staging desde GitHub Actions (OIDC, privilegio minimo)."

  assume_role_policy   = data.aws_iam_policy_document.github_deploy_trust.json
  max_session_duration = 3600
}

data "aws_iam_policy_document" "github_deploy" {
  # El token de inicio de sesion de ECR no admite restriccion por recurso.
  #checkov:skip=CKV_AWS_356:ecr:GetAuthorizationToken solo existe con Resource "*"; el resto de acciones esta acotado a dos repositorios.
  statement {
    sid       = "EcrLogin"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  statement {
    sid    = "EcrPublicarImagen"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:DescribeImages",
      "ecr:GetDownloadUrlForLayer",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = local.deploy_ecr_arns
  }

  statement {
    sid       = "EcsRedesplegar"
    effect    = "Allow"
    actions   = ["ecs:UpdateService"]
    resources = local.deploy_ecs_service_arns
  }

  statement {
    sid       = "EcsConsultarServicios"
    effect    = "Allow"
    actions   = ["ecs:DescribeServices"]
    resources = local.deploy_ecs_service_arns
  }

  statement {
    sid       = "EcsConsultarTareas"
    effect    = "Allow"
    actions   = ["ecs:DescribeTasks", "ecs:ListTasks"]
    resources = ["*"]

    condition {
      test     = "ArnEquals"
      variable = "ecs:cluster"
      values   = [local.deploy_ecs_cluster_arn]
    }
  }
}

resource "aws_iam_role_policy" "github_deploy" {
  name   = "despliegue-staging"
  role   = aws_iam_role.github_deploy.id
  policy = data.aws_iam_policy_document.github_deploy.json
}
