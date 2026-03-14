locals {
  # oidc_provider_url is passed without the https:// prefix (matching eks module output)
  oidc_host = var.oidc_provider_url
}

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "eso_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:sub"
      values   = ["system:serviceaccount:${var.eso_namespace}:${var.eso_service_account_name}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_host}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "eso" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.eso_trust.json
  tags               = var.tags
}

data "aws_iam_policy_document" "eso_secrets" {
  statement {
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = ["arn:aws:secretsmanager:*:${data.aws_caller_identity.current.account_id}:secret:${var.secret_path_prefix}/*"]
  }
}

resource "aws_iam_role_policy" "eso_secrets" {
  name   = "eso-secrets-access"
  role   = aws_iam_role.eso.id
  policy = data.aws_iam_policy_document.eso_secrets.json
}
