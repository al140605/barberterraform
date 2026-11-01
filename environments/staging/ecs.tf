# T026 - ECS Fargate de staging: clúster y los servicios barber y frontend.
# Todo se IMPORTA; el despliegue de las aplicaciones sigue siendo del pipeline (docker push a ECR y
# `ecs update-service --force-new-deployment`). Por eso:
#   - la definicion de tarea NO se administra aqui: se lee la ultima revision activa de cada familia (data source) y
#     el servicio ignora los cambios de task_definition y desired_count;
#   - el servicio ollama queda fuera de este alcance.

locals {
  ecs_services = {
    barber = {
      service        = "uba-stg-barber"
      family         = "urbanblade-staging-barber"
      container      = "barber"
      container_port = 80
      grace_seconds  = 180
      target_group   = "barber"
    }
    frontend = {
      service        = "uba-stg-frontend"
      family         = "urbanblade-staging-frontend"
      container      = "frontend-urban"
      container_port = 3000
      grace_seconds  = 90
      target_group   = "frontend"
    }
  }
}

resource "aws_ecs_cluster" "staging" {
  name = "urbanblade-staging"

  setting {
    name  = "containerInsights"
    value = "disabled"
  }

  #checkov:skip=CKV_AWS_65:Container Insights apagado hoy (costo en staging); se importa sin cambios.

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_ecs_cluster_capacity_providers" "staging" {
  cluster_name       = aws_ecs_cluster.staging.name
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 1
    base              = 0
  }
}

# Ultima revision activa de cada familia: solo para satisfacer el argumento obligatorio del servicio al importar.
data "aws_ecs_task_definition" "service" {
  for_each = local.ecs_services

  task_definition = each.value.family
}

resource "aws_ecs_service" "staging" {
  for_each = local.ecs_services

  name            = each.value.service
  cluster         = aws_ecs_cluster.staging.id
  task_definition = data.aws_ecs_task_definition.service[each.key].arn
  desired_count   = 1

  scheduling_strategy                = "REPLICA"
  platform_version                   = "LATEST"
  enable_execute_command             = false
  enable_ecs_managed_tags            = false
  propagate_tags                     = "NONE"
  health_check_grace_period_seconds  = each.value.grace_seconds
  deployment_minimum_healthy_percent = 100
  deployment_maximum_percent         = 200

  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight            = 1
    base              = 0
  }

  deployment_circuit_breaker {
    enable   = false
    rollback = false
  }

  network_configuration {
    subnets          = [for az in sort(keys(data.aws_subnet.staging)) : data.aws_subnet.staging[az].id]
    security_groups  = [aws_security_group.tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.staging[each.value.target_group].arn
    container_name   = each.value.container
    container_port   = each.value.container_port
  }

  #checkov:skip=CKV_AWS_333:Las tareas necesitan IP publica: la VPC es la predeterminada y no hay NAT ni VPC endpoints.

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [task_definition, desired_count]
  }
}

import {
  to = aws_ecs_cluster.staging
  id = "urbanblade-staging"
}

import {
  to = aws_ecs_cluster_capacity_providers.staging
  id = "urbanblade-staging"
}

import {
  for_each = local.ecs_services

  to = aws_ecs_service.staging[each.key]
  id = "urbanblade-staging/${each.value.service}"
}
