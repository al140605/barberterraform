locals {
  ecr_repositories = toset([
    "urbanblade/barber",
    "urbanblade/frontend-urban",
    "urbanblade/spark"
  ])

  log_groups = toset([
    "/ecs/urbanblade-staging/barber",
    "/ecs/urbanblade-staging/frontend-urban",
    "/ecs/urbanblade-staging/spark"
  ])
}

resource "aws_ecr_repository" "application" {
  for_each = local.ecr_repositories

  name = each.value

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_cloudwatch_log_group" "application" {
  for_each = local.log_groups

  name = each.value

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
  to = aws_ecr_repository.application["urbanblade/spark"]
  id = "urbanblade/spark"
}

import {
  to = aws_cloudwatch_log_group.application["/ecs/urbanblade-staging/barber"]
  id = "/ecs/urbanblade-staging/barber"
}

import {
  to = aws_cloudwatch_log_group.application["/ecs/urbanblade-staging/frontend-urban"]
  id = "/ecs/urbanblade-staging/frontend-urban"
}

import {
  to = aws_cloudwatch_log_group.application["/ecs/urbanblade-staging/spark"]
  id = "/ecs/urbanblade-staging/spark"
}