# Analisis estatico de Terraform (T030). Uso, desde la raiz del repo:
#   tflint --init
#   tflint --chdir=bootstrap/state
#   tflint --chdir=environments/staging
# --chdir cambia a ese directorio, asi que se pasa --config para usar este archivo:
#   tflint --chdir=environments/staging --config="$(pwd)/.tflint.hcl"
config {
  call_module_type = "none"
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "aws" {
  enabled = true
  version = "0.38.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}
