variable "oidc_provider_arn" {
  description = "ARN of the EKS cluster OIDC provider (from eks module output)"
  type        = string
}

variable "oidc_provider_url" {
  description = "URL of the EKS cluster OIDC provider WITHOUT https:// (from eks module output)"
  type        = string
}

variable "role_name" {
  description = "Name for the ESO IAM role"
  type        = string
  default     = "openshelter-eso-irsa"
}

variable "eso_namespace" {
  description = "Kubernetes namespace where ESO is installed"
  type        = string
  default     = "external-secrets"
}

variable "eso_service_account_name" {
  description = "Name of the ESO controller service account"
  type        = string
  default     = "external-secrets"
}

variable "secret_path_prefix" {
  description = "Prefix for Secrets Manager paths this role may read (e.g. openshelter-dev)"
  type        = string
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}
