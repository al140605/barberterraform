# T024 - ALB de staging, con sus target groups y listeners.
# Todo existe en AWS y se IMPORTA; los valores replican lo que hay hoy para que el primer plan no proponga cambios.
# CloudFront es quien publica estos puertos (80 frontend, 8080 API); el ALB solo acepta CloudFront por
# los grupos de seguridad de network.tf.

locals {
  target_groups = {
    barber   = { port = 80, health_path = "/up" }
    frontend = { port = 3000, health_path = "/api/health" }
  }

  # Puerto del listener -> target group al que reenvia por defecto.
  alb_listeners = {
    "80"   = "frontend"
    "8080" = "barber"
  }
}

resource "aws_lb" "staging" {
  name               = "urbanblade-staging"
  internal           = false
  load_balancer_type = "application"
  ip_address_type    = "ipv4"

  security_groups = [for port in sort(keys(aws_security_group.alb_cloudfront)) : aws_security_group.alb_cloudfront[port].id]
  subnets         = [for az in sort(keys(data.aws_subnet.staging)) : data.aws_subnet.staging[az].id]

  idle_timeout                     = 60
  enable_deletion_protection       = false
  drop_invalid_header_fields       = false
  enable_http2                     = true
  enable_cross_zone_load_balancing = true
  desync_mitigation_mode           = "defensive"

  #checkov:skip=CKV_AWS_150:Se importa tal cual (sin proteccion contra borrado); prevent_destroy cubre Terraform. Evaluar activarla.
  #checkov:skip=CKV_AWS_91:Sin registros de acceso hoy; pendiente (requiere bucket de logs y politica).
  #checkov:skip=CKV_AWS_131:Se importa tal cual; activar el descarte de encabezados invalidos es un cambio aparte, con prueba.
  #checkov:skip=CKV2_AWS_28:Sin WAF en el ALB; solo acepta trafico de CloudFront por grupo de seguridad.
  #checkov:skip=CKV2_AWS_20:El ALB no recibe trafico directo del usuario: CloudFront publica el HTTPS y habla HTTP con el origen. Pendiente migrar el origen a HTTPS.

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_lb_target_group" "staging" {
  for_each = local.target_groups

  name                 = "uba-stg-${each.key}"
  port                 = each.value.port
  protocol             = "HTTP"
  target_type          = "ip"
  vpc_id               = data.aws_vpc.default.id
  deregistration_delay = 300

  health_check {
    enabled             = true
    path                = each.value.health_path
    port                = "traffic-port"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 5
    matcher             = "200"
  }

  #checkov:skip=CKV_AWS_378:El ALB habla HTTP con las tareas dentro de la VPC; pasar a HTTPS exige certificados en las tareas.

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_lb_listener" "staging" {
  for_each = local.alb_listeners

  load_balancer_arn = aws_lb.staging.arn
  port              = tonumber(each.key)
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.staging[each.value].arn
  }

  #checkov:skip=CKV_AWS_2:El origen de CloudFront usa HTTP hacia el ALB; pasar a HTTPS exige certificado ACM y cambiar el origen. Pendiente.
  #checkov:skip=CKV_AWS_103:Listener HTTP; no aplica TLS 1.2 hasta migrar a HTTPS.

  lifecycle {
    prevent_destroy = true
  }
}

import {
  to = aws_lb.staging
  id = "arn:aws:elasticloadbalancing:us-east-1:209479293733:loadbalancer/app/urbanblade-staging/0e4177dc681b9f23"
}

import {
  for_each = {
    barber   = "arn:aws:elasticloadbalancing:us-east-1:209479293733:targetgroup/uba-stg-barber/5c76f0f4d408f965"
    frontend = "arn:aws:elasticloadbalancing:us-east-1:209479293733:targetgroup/uba-stg-frontend/e961a12ce2ed3022"
  }

  to = aws_lb_target_group.staging[each.key]
  id = each.value
}

import {
  for_each = {
    "80"   = "arn:aws:elasticloadbalancing:us-east-1:209479293733:listener/app/urbanblade-staging/0e4177dc681b9f23/4079518007d80e77"
    "8080" = "arn:aws:elasticloadbalancing:us-east-1:209479293733:listener/app/urbanblade-staging/0e4177dc681b9f23/b58e7de00f503b8a"
  }

  to = aws_lb_listener.staging[each.key]
  id = each.value
}
