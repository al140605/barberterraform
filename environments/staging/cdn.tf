# T120 - CloudFront de staging: una distribucion por servicio publico (frontend, API y spark).
# Las tres existen en AWS y se IMPORTAN; los valores replican lo que hay hoy para que el primer plan no proponga cambios
# (salvo las etiquetas por defecto del proveedor, que se agregan en sitio). Las tres usan el mismo origen (el ALB de
# alb.tf) y se distinguen por el puerto del listener: 80 frontend, 8080 API, 8501 spark.
#
# El certificado ACM (us-east-1, con los tres dominios) se referencia por ARN: se creo y valido a mano en ACM y no se
# administra aqui. Sin cabeceras personalizadas hacia el origen: el ALB solo acepta CloudFront por grupo de seguridad.

locals {
  cloudfront_certificate_arn = "arn:aws:acm:us-east-1:209479293733:certificate/3ae3fb28-55fd-40c9-9488-ef8276513fe2"

  # Politicas administradas por AWS: CachingDisabled y AllViewer (todo pasa al origen, nada se cachea en el borde).
  cloudfront_cache_policy_id          = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
  cloudfront_origin_request_policy_id = "216adef6-5c7f-47e4-b989-5492eafa07d3"

  cloudfront_distributions = {
    frontend = {
      id        = "E1LFM8ET3R2TF3"
      comment   = "UrbanBlade staging frontend"
      aliases   = ["urbanblade.com.mx", "www.urbanblade.com.mx"]
      origin_id = "alb-frontend"
      http_port = 80
    }
    api = {
      id        = "E3VPZXBKIE3G5T"
      comment   = "UrbanBlade staging api"
      aliases   = ["api.urbanblade.com.mx"]
      origin_id = "alb-api"
      http_port = 8080
    }
    spark = {
      id        = "E1WK7UCZ9FYH79"
      comment   = "UrbanBlade staging spark"
      aliases   = ["spark.urbanblade.com.mx"]
      origin_id = "alb-spark"
      http_port = 8501
    }
  }
}

resource "aws_cloudfront_distribution" "staging" {
  for_each = local.cloudfront_distributions

  enabled         = true
  is_ipv6_enabled = true
  http_version    = "http2"
  price_class     = "PriceClass_100"
  comment         = each.value.comment
  aliases         = each.value.aliases

  origin {
    origin_id           = each.value.origin_id
    domain_name         = aws_lb.staging.dns_name
    connection_attempts = 3
    connection_timeout  = 10

    custom_origin_config {
      http_port                = each.value.http_port
      https_port               = 443
      origin_protocol_policy   = "http-only"
      origin_ssl_protocols     = ["TLSv1", "TLSv1.1", "TLSv1.2"]
      origin_read_timeout      = 60
      origin_keepalive_timeout = 5
    }
  }

  default_cache_behavior {
    target_origin_id         = each.value.origin_id
    viewer_protocol_policy   = "redirect-to-https"
    allowed_methods          = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods           = ["GET", "HEAD"]
    compress                 = true
    cache_policy_id          = local.cloudfront_cache_policy_id
    origin_request_policy_id = local.cloudfront_origin_request_policy_id
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = local.cloudfront_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  #checkov:skip=CKV_AWS_86:Sin registros de acceso hoy; pendiente (requiere bucket de logs con ACL para CloudFront).
  #checkov:skip=CKV_AWS_68:Sin WAF hoy; pendiente evaluar costo y reglas.
  #checkov:skip=CKV_AWS_310:Un solo origen (el ALB); no hay segundo origen al que conmutar.
  #checkov:skip=CKV_AWS_374:Sin restriccion geografica: la barberia atiende publico general.
  #checkov:skip=CKV2_AWS_32:Sin politica de cabeceras de respuesta; las cabeceras de seguridad las pone la aplicacion.
  #checkov:skip=CKV2_AWS_47:Sin WAF, por lo tanto sin regla de Log4j; el origen es PHP y Nuxt, no Java.
  #checkov:skip=CKV_AWS_305:El frontend resuelve la raiz en el origen (Nuxt); no hay objeto raiz que servir desde el borde.

  lifecycle {
    prevent_destroy = true
  }
}

import {
  for_each = local.cloudfront_distributions

  to = aws_cloudfront_distribution.staging[each.key]
  id = each.value.id
}
