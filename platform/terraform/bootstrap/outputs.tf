output "state_bucket_name" {
  value       = aws_s3_bucket.terraform_state.id
  description = "S3 bucket used for Terraform remote state"
}

output "lock_table_name" {
  value       = aws_dynamodb_table.terraform_lock.name
  description = "DynamoDB table used for state locking"
}

output "tf_plan_role_arn" {
  value       = module.github_oidc.tf_plan_role_arn
  description = "Set as TF_PLAN_ROLE_ARN GitHub Actions secret"
}

output "ecr_push_role_arn" {
  value       = module.github_oidc.ecr_push_role_arn
  description = "Set as ECR_PUSH_ROLE_ARN GitHub Actions secret"
}
