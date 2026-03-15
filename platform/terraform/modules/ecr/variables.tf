variable "repository_names" {
  type        = list(string)
  description = "List of ECR repository names to create"
}

variable "create_repositories" {
  type        = bool
  description = "When true, create ECR repositories; when false, reference existing repositories"
  default     = true
}

variable "tags" {
  type        = map(string)
  description = "Resource tags"
  default     = {}
}
