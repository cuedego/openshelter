variable "github_org" {
  type        = string
  description = "GitHub organization or user that owns the repository (e.g. cuedego)"
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name (e.g. openshelter)"
}

variable "tf_plan_role_name" {
  type        = string
  description = "Name of the IAM role assumed by the terraform-plan job"
  default     = "openshelter-github-tf-plan"
}

variable "ecr_push_role_name" {
  type        = string
  description = "Name of the IAM role assumed by the docker-build-push job"
  default     = "openshelter-github-ecr-push"
}

variable "state_bucket_name" {
  type        = string
  description = "Terraform state S3 bucket name — added to the plan role policy"
}

variable "lock_table_name" {
  type        = string
  description = "Terraform state lock DynamoDB table — added to the plan role policy"
}

variable "tags" {
  type        = map(string)
  description = "Resource tags"
  default     = {}
}
