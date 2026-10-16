# Comprobacion offline (sin credenciales de AWS): el workspace `default` debe ser rechazado por la guarda, de modo que
# no se pueda crear nada con un nombre que no sea eph-*. Uso:  terraform -chdir=environments/ephemeral test
# IMPORTANTE: el nombre sale de `terraform.workspace`, asi que la prueba solo es valida con el workspace `default`
# seleccionado (con eph-* la guarda pasa y la prueba falla a proposito). Comprobar con: terraform workspace show
mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "209479293733"
    }
  }

  mock_data "aws_vpc" {
    defaults = {
      id = "vpc-00000000"
    }
  }
}

variables {
  aws_account_id = "209479293733"
}

run "workspace_default_es_rechazado" {
  command = plan

  expect_failures = [
    terraform_data.guard,
  ]
}
