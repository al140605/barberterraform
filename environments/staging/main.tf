data "aws_caller_identity" "current" {}

check "expected_aws_account" {
  assert {
    condition     = data.aws_caller_identity.current.account_id == var.aws_account_id
    error_message = "Las credenciales AWS activas no pertenecen a aws_account_id."
  }
}