variable "oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider (from eks module output)"
  type        = string
}

variable "oidc_provider_url" {
  description = "URL of the EKS OIDC provider, without https:// prefix"
  type        = string
}

variable "role_name" {
  description = "Name for the IRSA IAM role"
  type        = string
}

variable "service_account_namespace" {
  description = "Kubernetes namespace where the ALB controller service account lives"
  type        = string
  default     = "kube-system"
}

variable "service_account_name" {
  description = "Kubernetes service account name for the ALB controller"
  type        = string
  default     = "aws-load-balancer-controller"
}

variable "tags" {
  description = "Tags applied to all IAM resources"
  type        = map(string)
  default     = {}
}
