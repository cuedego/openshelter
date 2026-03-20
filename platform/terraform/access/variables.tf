variable "region" {
  description = "AWS region for EKS access management"
  type        = string
}

variable "bootstrap_role_arn" {
  description = "IAM role ARN granted cluster-admin access on all managed EKS clusters"
  type        = string
}

variable "environments" {
  description = "Environment names to manage EKS bootstrap access"
  type        = list(string)
  default     = ["dev", "stg", "prod"]
}

variable "cluster_name_prefix" {
  description = "Cluster name prefix used to compute EKS cluster names"
  type        = string
  default     = "openshelter"
}
