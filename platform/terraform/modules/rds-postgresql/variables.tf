variable "identifier" {
  type        = string
  description = "RDS instance identifier"
}

variable "db_name" {
  type        = string
  description = "Initial database name"
}

variable "username" {
  type        = string
  description = "Master username"
}

variable "password" {
  type        = string
  description = "Master password"
  sensitive   = true
}

variable "instance_class" {
  type        = string
  description = "RDS instance class"
  default     = "db.t4g.micro"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where the RDS instance will be placed"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR block used in the security group ingress rule"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for the DB subnet group"
}

variable "tags" {
  type        = map(string)
  description = "Resource tags"
  default     = {}
}
