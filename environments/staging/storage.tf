# T120 - Buckets S3 de la plataforma: archivos publicos (fotos de trabajos, avatares) y recibos privados.
# Existen en AWS y se IMPORTAN; la configuracion replica lo que hay hoy. El bucket de respaldos de la Fase 5
# (urbanblade-backups-*) queda fuera: no es parte de la plataforma web y tiene su propio ciclo de vida.
#
# Hoy ninguno tiene versionado, ciclo de vida, CORS ni etiquetas propias; no se declaran para no cambiar nada. El
# bloqueo de acceso publico de "uploads" es parcial a proposito: sirve imagenes por URL publica (solo GetObject).

locals {
  storage_buckets = {
    uploads  = { name = "urbanblade-staging-uploads-${var.aws_account_id}", block_public_policy = false }
    receipts = { name = "urbanblade-staging-receipts-${var.aws_account_id}", block_public_policy = true }
  }
}

resource "aws_s3_bucket" "storage" {
  for_each = local.storage_buckets

  bucket = each.value.name

  #checkov:skip=CKV_AWS_18:Sin registros de acceso del bucket hoy; pendiente (requiere bucket de logs).
  #checkov:skip=CKV_AWS_21:Sin versionado hoy; activarlo es un cambio aparte (costo de almacenamiento y ciclo de vida).
  #checkov:skip=CKV_AWS_144:Sin replicacion entre regiones; staging de una sola region.
  #checkov:skip=CKV2_AWS_61:Sin ciclo de vida hoy; pendiente definir retencion de archivos.
  #checkov:skip=CKV2_AWS_62:Sin notificaciones de eventos; la aplicacion no las usa.
  #checkov:skip=CKV_AWS_145:Cifrado con clave administrada por S3 (AES256), igual que hoy; KMS propio queda pendiente.

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "storage" {
  for_each = aws_s3_bucket.storage

  bucket = each.value.id

  rule {
    bucket_key_enabled = false

    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "storage" {
  for_each = aws_s3_bucket.storage

  bucket                  = each.value.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = local.storage_buckets[each.key].block_public_policy
  restrict_public_buckets = local.storage_buckets[each.key].block_public_policy

  #checkov:skip=CKV_AWS_54:uploads sirve imagenes publicas por politica (solo GetObject); receipts si bloquea todo.
  #checkov:skip=CKV_AWS_56:uploads sirve imagenes publicas por politica (solo GetObject); receipts si bloquea todo.
}

resource "aws_s3_bucket_ownership_controls" "storage" {
  for_each = aws_s3_bucket.storage

  bucket = each.value.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Lectura publica de los objetos de "uploads" (fotos de trabajos del muro y avatares). Solo GetObject, sin listado.
resource "aws_s3_bucket_policy" "uploads_public_read" {
  bucket = aws_s3_bucket.storage["uploads"].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "PublicRead"
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.storage["uploads"].arn}/*"
    }]
  })

  #checkov:skip=CKV_AWS_70:Lectura publica intencional del bucket de imagenes; solo GetObject, sin escritura ni listado.
  #checkov:skip=CKV_AWS_283:Lectura publica intencional del bucket de imagenes; solo GetObject, sin escritura ni listado.
}

import {
  for_each = local.storage_buckets

  to = aws_s3_bucket.storage[each.key]
  id = each.value.name
}

import {
  for_each = local.storage_buckets

  to = aws_s3_bucket_server_side_encryption_configuration.storage[each.key]
  id = each.value.name
}

import {
  for_each = local.storage_buckets

  to = aws_s3_bucket_public_access_block.storage[each.key]
  id = each.value.name
}

import {
  for_each = local.storage_buckets

  to = aws_s3_bucket_ownership_controls.storage[each.key]
  id = each.value.name
}

import {
  to = aws_s3_bucket_policy.uploads_public_read
  id = local.storage_buckets["uploads"].name
}
