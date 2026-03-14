variable "region" {
  description = "AWS region for bootstrap resources"
  type        = string
}

variable "state_bucket_name" {
  description = "Unique S3 bucket name for Terraform state"
  type        = string
}

variable "lock_table_name" {
  description = "DynamoDB table name for Terraform state lock"
  type        = string
}

variable "github_org" {
  description = "GitHub organization or user (e.g. cuedego)"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (e.g. openshelter)"
  type        = string
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
