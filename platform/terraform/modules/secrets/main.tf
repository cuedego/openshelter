locals {
  secret_values_from_aws = {
    for key in keys(data.aws_secretsmanager_secret_version.current) :
    key => data.aws_secretsmanager_secret_version.current[key].secret_string
  }

  effective_secret_values = {
    for key in keys(var.secret_configs) :
    key => var.use_existing_secret_values ? try(local.secret_values_from_aws[key], null) : try(var.secret_values[key], null)
  }
}

resource "aws_secretsmanager_secret" "this" {
  for_each = var.secret_configs

  name                    = "${var.name_prefix}/${each.key}"
  description             = each.value.description
  recovery_window_in_days = var.recovery_window_in_days

  tags = var.tags
}

data "aws_secretsmanager_secret_version" "current" {
  for_each = var.use_existing_secret_values ? var.secret_configs : {}

  secret_id = aws_secretsmanager_secret.this[each.key].id
}

resource "aws_secretsmanager_secret_version" "this" {
  for_each = var.secret_configs

  secret_id     = aws_secretsmanager_secret.this[each.key].id
  secret_string = local.effective_secret_values[each.key]

  lifecycle {
    precondition {
      condition     = local.effective_secret_values[each.key] != null
      error_message = "Secret value for ${each.key} must be provided on first apply or already exist in AWS Secrets Manager."
    }
  }
}
