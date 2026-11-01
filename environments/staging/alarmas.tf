# Alarmas y panel de disponibilidad de staging (frontend y barber).
#
# Hasta ahora las unicas alarmas eran las del autoescalado: nadie se enteraba si el sitio se caia, si el ALB devolvia 5xx o si
# las tareas quedaban sin salud. Estas alarmas avisan por correo (SNS). Como costos.tf, no dependen de los recursos importados
# de staging: se nombran por cadena y se aplican con -target. Solo se crean si se indican correos (alarm_alert_emails), para no
# guardar direcciones personales en un repositorio publico.
#
# Reglas para no generar ruido: los datos que faltan en las alarmas de errores cuentan como "sin error" (un servicio sin trafico
# no alarma) y la alarma de caida cuenta los datos faltantes como fallo. Un despliegue normal reemplaza la tarea en menos de tres
# minutos, asi que la caida exige tres periodos seguidos sin ningun host saludable.

locals {
  alarm_alb_suffix = "app/urbanblade-staging/0e4177dc681b9f23"

  alarm_target_groups = {
    frontend = { suffix = "targetgroup/uba-stg-frontend/e961a12ce2ed3022", service = "uba-stg-frontend" }
    barber   = { suffix = "targetgroup/uba-stg-barber/5c76f0f4d408f965", service = "uba-stg-barber" }
  }

  alarms_enabled = length(var.alarm_alert_emails) > 0
}

# SNS no se cifra con KMS: una alarma de CloudWatch no puede publicar en un tema cifrado con la clave administrada por AWS, y una
# clave propia costaria dinero por un tema que solo transporta nombres de alarmas.
resource "aws_sns_topic" "alarmas" {
  #checkov:skip=CKV_AWS_26:CloudWatch no puede publicar en un tema cifrado con la clave administrada aws/sns; el contenido no es sensible.
  count = local.alarms_enabled ? 1 : 0

  name = "${var.project_name}-${var.environment}-alarmas"
}

resource "aws_sns_topic_subscription" "alarmas_correo" {
  for_each = local.alarms_enabled ? toset(var.alarm_alert_emails) : toset([])

  topic_arn = aws_sns_topic.alarmas[0].arn
  protocol  = "email"
  endpoint  = each.value
}

# Caida: ningun host saludable en el target group durante tres minutos seguidos.
resource "aws_cloudwatch_metric_alarm" "sin_hosts_saludables" {
  for_each = local.alarms_enabled ? local.alarm_target_groups : {}

  alarm_name          = "${var.project_name}-${var.environment}-${each.key}-sin-hosts-saludables"
  alarm_description   = "El target group de ${each.key} no tiene ningun host saludable: el servicio esta caido o no responde a su chequeo de salud."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HealthyHostCount"
  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 3
  datapoints_to_alarm = 3
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "breaching"
  alarm_actions       = [aws_sns_topic.alarmas[0].arn]
  ok_actions          = [aws_sns_topic.alarmas[0].arn]

  dimensions = {
    LoadBalancer = local.alarm_alb_suffix
    TargetGroup  = each.value.suffix
  }
}

# Errores 5xx que devuelve la propia aplicacion.
resource "aws_cloudwatch_metric_alarm" "errores_5xx" {
  for_each = local.alarms_enabled ? local.alarm_target_groups : {}

  alarm_name          = "${var.project_name}-${var.environment}-${each.key}-errores-5xx"
  alarm_description   = "${each.key} devolvio 10 o mas errores 5xx en 5 minutos."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 10
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarmas[0].arn]
  ok_actions          = [aws_sns_topic.alarmas[0].arn]

  dimensions = {
    LoadBalancer = local.alarm_alb_suffix
    TargetGroup  = each.value.suffix
  }
}

# Errores 5xx que genera el balanceador (502/503/504): suelen indicar que no llego a ninguna tarea.
resource "aws_cloudwatch_metric_alarm" "errores_5xx_alb" {
  count = local.alarms_enabled ? 1 : 0

  alarm_name          = "${var.project_name}-${var.environment}-alb-errores-5xx"
  alarm_description   = "El balanceador genero 5 o mas errores 5xx en 5 minutos (no llego a las tareas)."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_ELB_5XX_Count"
  statistic           = "Sum"
  period              = 300
  evaluation_periods  = 1
  threshold           = 5
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarmas[0].arn]
  ok_actions          = [aws_sns_topic.alarmas[0].arn]

  dimensions = {
    LoadBalancer = local.alarm_alb_suffix
  }
}

# Lentitud: el percentil 95 del tiempo de respuesta supera 3 segundos durante 15 minutos.
resource "aws_cloudwatch_metric_alarm" "latencia" {
  for_each = local.alarms_enabled ? local.alarm_target_groups : {}

  alarm_name          = "${var.project_name}-${var.environment}-${each.key}-latencia-p95"
  alarm_description   = "El p95 de respuesta de ${each.key} supera 3 segundos durante 15 minutos."
  namespace           = "AWS/ApplicationELB"
  metric_name         = "TargetResponseTime"
  extended_statistic  = "p95"
  period              = 300
  evaluation_periods  = 3
  datapoints_to_alarm = 3
  threshold           = 3
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarmas[0].arn]
  ok_actions          = [aws_sns_topic.alarmas[0].arn]

  dimensions = {
    LoadBalancer = local.alarm_alb_suffix
    TargetGroup  = each.value.suffix
  }
}

# Memoria sostenida: el autoescalado reacciona a la CPU, no a la memoria; una fuga se vera aqui antes de que mate la tarea.
resource "aws_cloudwatch_metric_alarm" "memoria" {
  for_each = local.alarms_enabled ? local.alarm_target_groups : {}

  alarm_name          = "${var.project_name}-${var.environment}-${each.key}-memoria-alta"
  alarm_description   = "${each.key} usa mas del 85 % de su memoria durante 15 minutos."
  namespace           = "AWS/ECS"
  metric_name         = "MemoryUtilization"
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 3
  datapoints_to_alarm = 3
  threshold           = 85
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarmas[0].arn]
  ok_actions          = [aws_sns_topic.alarmas[0].arn]

  dimensions = {
    ClusterName = local.autoscaling_cluster
    ServiceName = each.value.service
  }
}

# Panel unico para mirar el estado de un vistazo.
resource "aws_cloudwatch_dashboard" "staging" {
  count = local.alarms_enabled ? 1 : 0

  dashboard_name = "${var.project_name}-${var.environment}"
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric", x = 0, y = 0, width = 12, height = 6
        properties = {
          title  = "Hosts saludables"
          region = "us-east-1"
          stat   = "Minimum"
          period = 60
          metrics = [for name, group in local.alarm_target_groups :
          ["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", local.alarm_alb_suffix, "TargetGroup", group.suffix, { label = name }]]
        }
      },
      {
        type = "metric", x = 12, y = 0, width = 12, height = 6
        properties = {
          title  = "Errores 5xx (aplicacion y balanceador)"
          region = "us-east-1"
          stat   = "Sum"
          period = 300
          metrics = concat(
            [for name, group in local.alarm_target_groups :
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", local.alarm_alb_suffix, "TargetGroup", group.suffix, { label = "${name} app" }]],
            [["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", local.alarm_alb_suffix, { label = "balanceador" }]]
          )
        }
      },
      {
        type = "metric", x = 0, y = 6, width = 12, height = 6
        properties = {
          title  = "Tiempo de respuesta p95 (s)"
          region = "us-east-1"
          stat   = "p95"
          period = 300
          metrics = [for name, group in local.alarm_target_groups :
          ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", local.alarm_alb_suffix, "TargetGroup", group.suffix, { label = name }]]
        }
      },
      {
        type = "metric", x = 12, y = 6, width = 12, height = 6
        properties = {
          title  = "CPU y memoria de los servicios (%)"
          region = "us-east-1"
          stat   = "Average"
          period = 300
          # concat une las dos listas de series sin aplanar cada serie (flatten las convertia en una lista de textos).
          metrics = concat(
            [for name, group in local.alarm_target_groups :
            ["AWS/ECS", "CPUUtilization", "ClusterName", local.autoscaling_cluster, "ServiceName", group.service, { label = "${name} CPU" }]],
            [for name, group in local.alarm_target_groups :
            ["AWS/ECS", "MemoryUtilization", "ClusterName", local.autoscaling_cluster, "ServiceName", group.service, { label = "${name} memoria" }]]
          )
        }
      }
    ]
  })
}
