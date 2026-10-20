# Estado remoto en el mismo bucket que staging. Cada ambiente efimero es un workspace de Terraform, asi que su
# estado queda en `env:/<workspace>/ephemeral/terraform.tfstate` y no se mezcla con el de staging.
terraform {
  backend "s3" {}
}
