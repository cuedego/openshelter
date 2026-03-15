output "oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC provider"
  value       = aws_iam_openid_connect_provider.github.arn
}

output "tf_plan_role_arn" {
  description = "IAM role ARN for the terraform-plan CI job — use as TF_PLAN_ROLE_ARN GitHub secret"
  value       = aws_iam_role.terraform_plan.arn
}

output "ecr_push_role_arn" {
  description = "IAM role ARN for the docker-build-push CI job — use as ECR_PUSH_ROLE_ARN GitHub secret"
  value       = aws_iam_role.ecr_push.arn
}

output "bootstrap_role_arn" {
  description = "IAM role ARN for the manual bootstrap workflow — use as BOOTSTRAP_ROLE_ARN GitHub environment secret"
  value       = aws_iam_role.bootstrap.arn
}
