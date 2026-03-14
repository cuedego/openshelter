variable "repository_names" {
  type        = list(string)
  description = "List of ECR repository names to create"
}

variable "tags" {
  type        = map(string)
  description = "Resource tags"
  default     = {}
}
