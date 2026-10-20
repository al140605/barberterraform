# T118 - MongoDB Atlas de staging: el clúster y los usuarios de base de datos.
# Todo existe en Atlas y se IMPORTA; este archivo NO crea ni cambia nada hasta que alguien revise el plan.
#
# Lo que se sabe esta documentado en barber/docs/MONGODB_ATLAS.md (clúster gratuito M0, 4 usuarios con privilegios por
# base). Lo que NO esta en ningun archivo del repo se pide por variable: ID del proyecto, nombre del clúster y region.
# Las credenciales de la API de Atlas las toma el proveedor de MONGODB_ATLAS_PUBLIC_API_KEY y
# MONGODB_ATLAS_PRIVATE_API_KEY; usar una llave con rol de solo lectura (Project Read Only) para el plan.
#
# Reglas que no se rompen:
#   - Nunca declarar contraseñas: viven en Secrets Manager y en los .env. Los usuarios llevan
#     ignore_changes = [password], asi que un plan jamas las toca ni las rota.
#   - prevent_destroy en todo: si la region o el nivel declarados no coinciden con Atlas, el plan debe FALLAR, no
#     proponer reemplazar el clúster (en M0 reemplazar = perder los datos; no hay respaldo en la nube).
#   - Fuera de alcance: el usuario personal `luis` (excepcion aceptada del propietario, 2026-09-23) y la lista de
#     acceso de red (hoy se desconoce su contenido; ver README).

locals {
  atlas_database_users = {
    laravel_core_rw = {
      username = "laravel_core_rw"
      role     = "readWrite"
      database = "barber_db"
    }
    laravel_analytics_reader = {
      username = "laravel_analytics_reader"
      role     = "read"
      database = "urbanblade_analytics"
    }
    spark_core_reader = {
      username = "spark_core_reader"
      role     = "read"
      database = "barber_db"
    }
    analytic = {
      username = "ANALYTIC"
      role     = "readWrite"
      database = "urbanblade_analytics"
    }
  }
}

resource "mongodbatlas_advanced_cluster" "staging" {
  project_id   = var.atlas_project_id
  name         = var.atlas_cluster_name
  cluster_type = "REPLICASET"

  # Clúster gratuito (M0): corre sobre AWS compartido. Sin respaldo en la nube ni restauracion a un punto en el tiempo.
  replication_specs = [{
    region_configs = [{
      provider_name         = "TENANT"
      backing_provider_name = "AWS"
      region_name           = var.atlas_region
      priority              = 7
      electable_specs = {
        instance_size = "M0"
      }
    }]
  }]

  lifecycle {
    prevent_destroy = true
  }
}

resource "mongodbatlas_database_user" "staging" {
  for_each = local.atlas_database_users

  project_id         = var.atlas_project_id
  username           = each.value.username
  auth_database_name = "admin"

  roles {
    role_name     = each.value.role
    database_name = each.value.database
  }

  lifecycle {
    prevent_destroy = true
    # La contraseña la gestiona otro proceso (Atlas + Secrets Manager); no debe pasar por el codigo ni por el estado.
    ignore_changes = [password]
  }
}

import {
  to = mongodbatlas_advanced_cluster.staging
  id = "${var.atlas_project_id}-${var.atlas_cluster_name}"
}

import {
  for_each = local.atlas_database_users

  to = mongodbatlas_database_user.staging[each.key]
  id = "${var.atlas_project_id}-${each.value.username}-admin"
}
