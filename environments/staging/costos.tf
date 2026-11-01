# Control de costos de staging: presupuesto con alertas y autoescalado de 1 a 2 tareas en frontend y barber.
#
# Contexto (31-oct-2026): un credito gratuito de 100 USD cubria buena parte de la factura y se agoto. El gasto real de un mes
# completo con 2 tareas por servicio y ollama rondaba 160 USD antes de IVA. Estas dos piezas evitan la sorpresa y pagan
# solo la capacidad que se usa. Como oidc_despliegue.tf y ecr_ciclo_de_vida.tf, no dependen de los recursos importados de
# staging: se nombran por cadena y se aplican con -target.

locals {
  # Servicios ECS que escalan por carga. Ollama queda fuera.
  autoscaling_cluster  = "${var.project_name}-${var.environment}"
  autoscaling_services = { frontend = "uba-stg-frontend", barber = "uba-stg-barber" }

  # Avisos del presupuesto: gasto real al 50, 80 y 100 % del limite, y pronostico al 100 %.
  budget_notifications = [
    { type = "ACTUAL", threshold = 50 },
    { type = "ACTUAL", threshold = 80 },
    { type = "ACTUAL", threshold = 100 },
    { type = "FORECASTED", threshold = 100 },
  ]
}

# Presupuesto mensual. Solo se crea si se indican correos: asi no hay direcciones personales en un repositorio publico; se pasan
# al aplicar (-var o terraform.tfvars, que Git ignora). Los dos primeros presupuestos de una cuenta son gratuitos.
resource "aws_budgets_budget" "mensual" {
  count = length(var.budget_alert_emails) > 0 ? 1 : 0

  name         = "${var.project_name}-${var.environment}-mensual"
  budget_type  = "COST"
  limit_amount = tostring(var.budget_limit_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  # Mide el gasto de uso real, sin restar creditos: con credito la factura se ve mas baja de lo que el servicio cuesta, y ese
  # fue el origen de la sorpresa. Incluye impuestos (IVA) y soporte.
  cost_types {
    include_credit             = false
    include_discount           = true
    include_other_subscription = true
    include_recurring          = true
    include_refund             = false
    include_subscription       = true
    include_support            = true
    include_tax                = true
    include_upfront            = true
    use_amortized              = false
    use_blended                = false
  }

  dynamic "notification" {
    for_each = local.budget_notifications

    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = notification.value.threshold
      threshold_type             = "PERCENTAGE"
      notification_type          = notification.value.type
      subscriber_email_addresses = var.budget_alert_emails
    }
  }
}

# Autoescalado: de 1 a 2 tareas segun la CPU. Con poca carga corre 1 (la mitad del costo de computo y de IPv4 publicas) y sube a 2
# cuando la CPU promedio pasa de 60 %; baja con calma (5 min) para no oscilar. El despliegue sigue sin cortes: minimo sano 100 % y
# maximo 200 % hacen que la tarea nueva arranque antes de parar la vieja.
resource "aws_appautoscaling_target" "ecs" {
  for_each = local.autoscaling_services

  service_namespace  = "ecs"
  scalable_dimension = "ecs:service:DesiredCount"
  resource_id        = "service/${local.autoscaling_cluster}/${each.value}"
  min_capacity       = var.autoscaling_min_tasks
  max_capacity       = var.autoscaling_max_tasks
}

resource "aws_appautoscaling_policy" "cpu" {
  for_each = local.autoscaling_services

  name               = "${each.value}-cpu"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = aws_appautoscaling_target.ecs[each.key].service_namespace
  scalable_dimension = aws_appautoscaling_target.ecs[each.key].scalable_dimension
  resource_id        = aws_appautoscaling_target.ecs[each.key].resource_id

  target_tracking_scaling_policy_configuration {
    target_value       = 60
    scale_out_cooldown = 60
    scale_in_cooldown  = 300

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}
