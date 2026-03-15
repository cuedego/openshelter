variable "name" {
  type        = string
  description = "EKS cluster name"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for the EKS control plane and node group"
}

variable "node_instance_types" {
  type        = list(string)
  description = "EC2 instance types for the managed node group"
  default     = ["t3.medium"]
}

variable "node_desired_size" {
  type        = number
  description = "Desired number of nodes"
  default     = 2
}

variable "node_min_size" {
  type        = number
  description = "Minimum number of nodes"
  default     = 1
}

variable "node_max_size" {
  type        = number
  description = "Maximum number of nodes"
  default     = 4
}

variable "tags" {
  type        = map(string)
  description = "Resource tags"
  default     = {}
}

variable "cluster_admin_principal_arns" {
  type        = list(string)
  description = "IAM principal ARNs granted cluster-admin access through EKS access entries"
  default     = []
}

