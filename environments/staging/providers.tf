provider "aws" {
  region              = var.aws_region
  allowed_account_ids = [var.aws_account_id]

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# Las credenciales las toma el propio proveedor de MONGODB_ATLAS_PUBLIC_API_KEY y MONGODB_ATLAS_PRIVATE_API_KEY.
# Hoy ningun recurso de Atlas se administra aqui, asi que `terraform plan` no las exige.
provider "mongodbatlas" {}