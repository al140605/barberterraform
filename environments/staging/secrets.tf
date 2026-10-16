# T026 - Secretos de barber en Secrets Manager (urbanblade/staging/barber/*).
# Se importan SOLO los secretos (contenedores), nunca su valor. Esta prohibido declarar
# `aws_secretsmanager_secret_version` para ellos: el valor lo gestiona otro proceso y no debe pasar por el codigo
# ni por el estado. Las definiciones de tarea de ECS los leen por ARN.
# Los secretos de spark (urbanblade/staging/spark/*) quedan fuera de este alcance.

locals {
  barber_secrets = {
    "urbanblade/staging/barber/ANALYTICS_MONGODB_URI"     = "arn:aws:secretsmanager:us-east-1:209479293733:secret:urbanblade/staging/barber/ANALYTICS_MONGODB_URI-jzWn0n"
    "urbanblade/staging/barber/APP_KEY"                   = "arn:aws:secretsmanager:us-east-1:209479293733:secret:urbanblade/staging/barber/APP_KEY-zDBG09"
    "urbanblade/staging/barber/FIREBASE_CREDENTIALS_JSON" = "arn:aws:secretsmanager:us-east-1:209479293733:secret:urbanblade/staging/barber/FIREBASE_CREDENTIALS_JSON-wkFQXI"
    "urbanblade/staging/barber/GOOGLE_CLIENT_ID"          = "arn:aws:secretsmanager:us-east-1:209479293733:secret:urbanblade/staging/barber/GOOGLE_CLIENT_ID-SzEYDh"
    "urbanblade/staging/barber/GOOGLE_CLIENT_SECRET"      = "arn:aws:secretsmanager:us-east-1:209479293733:secret:urbanblade/staging/barber/GOOGLE_CLIENT_SECRET-FC9wqF"
    "urbanblade/staging/barber/MAIL_PASSWORD"             = "arn:aws:secretsmanager:us-east-1:209479293733:secret:urbanblade/staging/barber/MAIL_PASSWORD-9QX0ak"
    "urbanblade/staging/barber/MONGODB_URI"               = "arn:aws:secretsmanager:us-east-1:209479293733:secret:urbanblade/staging/barber/MONGODB_URI-EjtnmH"
    "urbanblade/staging/barber/STRIPE_KEY"                = "arn:aws:secretsmanager:us-east-1:209479293733:secret:urbanblade/staging/barber/STRIPE_KEY-fR14Ij"
    "urbanblade/staging/barber/STRIPE_SECRET"             = "arn:aws:secretsmanager:us-east-1:209479293733:secret:urbanblade/staging/barber/STRIPE_SECRET-05NIyD"
    "urbanblade/staging/barber/STRIPE_WEBHOOK_SECRET"     = "arn:aws:secretsmanager:us-east-1:209479293733:secret:urbanblade/staging/barber/STRIPE_WEBHOOK_SECRET-iQj7HH"
    "urbanblade/staging/barber/VAPID_PRIVATE_KEY"         = "arn:aws:secretsmanager:us-east-1:209479293733:secret:urbanblade/staging/barber/VAPID_PRIVATE_KEY-4E590N"
    "urbanblade/staging/barber/VAPID_PUBLIC_KEY"          = "arn:aws:secretsmanager:us-east-1:209479293733:secret:urbanblade/staging/barber/VAPID_PUBLIC_KEY-5znbum"
  }
}

resource "aws_secretsmanager_secret" "barber" {
  for_each = local.barber_secrets

  name = each.key

  #checkov:skip=CKV_AWS_149:Cifrado con la llave administrada por AWS (aws/secretsmanager); una llave propia exige KMS y permisos. Pendiente.
  #checkov:skip=CKV2_AWS_57:Sin rotacion automatica: los valores los gestiona el propietario (Stripe, Google, Atlas); pendiente de evaluar.

  lifecycle {
    prevent_destroy = true
  }
}

import {
  for_each = local.barber_secrets

  to = aws_secretsmanager_secret.barber[each.key]
  id = each.value
}
