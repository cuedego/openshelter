# Fetch the TLS thumbprint of GitHub's OIDC endpoint dynamically so we never
# need to hard-code a value that can rotate.
data "tls_certificate" "github" {
  url = "https://token.actions.githubusercontent.com"
}

# ── GitHub OIDC Identity Provider ──────────────────────────────────────────────

resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.github.certificates[0].sha1_fingerprint]

  tags = var.tags
}

# ── IAM role: terraform-plan (pull-request + environment scope) ────────────────
#
# Trusted for internal pull_request runs and for runs attached to the configured
# GitHub Environment. Common subject claims:
#   repo:<org>/<repo>:pull_request
#   repo:<org>/<repo>:environment:<env>

resource "aws_iam_role" "terraform_plan" {
  name = var.tf_plan_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = [
            "repo:${var.github_org}/${var.github_repo}:pull_request",
            "repo:${var.github_org}/${var.github_repo}:environment:${var.tf_plan_environment_name}",
          ]
        }
      }
    }]
  })

  tags = var.tags
}

# ReadOnlyAccess lets terraform plan read all resources without being able to
# create, update or destroy anything.
resource "aws_iam_role_policy_attachment" "terraform_plan_readonly" {
  role       = aws_iam_role.terraform_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

# Terraform also needs to read/write the state lock table and the state bucket.
resource "aws_iam_role_policy" "terraform_plan_state" {
  name = "terraform-state-access"
  role = aws_iam_role.terraform_plan.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3StateRead"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
        ]
        Resource = [
          "arn:aws:s3:::${var.state_bucket_name}",
          "arn:aws:s3:::${var.state_bucket_name}/*",
        ]
      },
      {
        Sid    = "DynamoDBLock"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
        ]
        Resource = "arn:aws:dynamodb:*:*:table/${var.lock_table_name}"
      },
    ]
  })
}

# ── IAM role: ecr-push (main branch + environment scope) ───────────────────────
#
# Trusted when the workflow runs on main and when attached to the configured
# GitHub Environment. Common subject claims:
#   repo:<org>/<repo>:ref:refs/heads/main
#   repo:<org>/<repo>:environment:<env>

resource "aws_iam_role" "ecr_push" {
  name = var.ecr_push_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = [
            "repo:${var.github_org}/${var.github_repo}:ref:refs/heads/main",
            "repo:${var.github_org}/${var.github_repo}:environment:${var.ecr_push_environment_name}",
          ]
        }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "ecr_push" {
  name = "ecr-push"
  role = aws_iam_role.ecr_push.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ECRAuth"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Sid    = "ECRPush"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
        ]
        Resource = "arn:aws:ecr:*:*:repository/openshelter/*"
      },
    ]
  })
}
