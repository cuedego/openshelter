variable "name" {
  type        = string
  description = "Name prefix for networking resources"
}

variable "cidr_block" {
  type        = string
  description = "VPC CIDR block"
}

variable "tags" {
  type        = map(string)
  description = "Resource tags"
  default     = {}
}
