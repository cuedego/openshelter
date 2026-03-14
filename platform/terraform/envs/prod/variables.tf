variable "region" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "eks_cluster_role_arn" {
  type = string
}

variable "eks_subnet_ids" {
  type = list(string)
}

variable "rds_password" {
  type      = string
  sensitive = true
}
