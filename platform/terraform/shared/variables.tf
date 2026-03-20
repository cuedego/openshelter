variable "region" {
  description = "AWS region for shared resources"
  type        = string
}

variable "repository_names" {
  description = "Shared ECR repositories managed outside environment stacks"
  type        = list(string)
  default     = ["openshelter/zabbix", "openshelter/mqtt"]
}
