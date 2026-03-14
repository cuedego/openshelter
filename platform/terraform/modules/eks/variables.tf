variable "name" {
  type        = string
  description = "EKS cluster name"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "cluster_role_arn" {
  type        = string
  description = "IAM role ARN used by the EKS control plane"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnets used by the EKS control plane"
}

variable "tags" {
  type        = map(string)
  description = "Resource tags"
  default     = {}
}
