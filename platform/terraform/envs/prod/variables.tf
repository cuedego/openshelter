variable "region" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "rds_password" {
  type      = string
  sensitive = true
}

variable "zabbix_admin_password" {
  type        = string
  sensitive   = true
  description = "Zabbix admin user password stored in AWS Secrets Manager"
}

variable "mqtt_password" {
  type        = string
  sensitive   = true
  description = "MQTT broker authentication password stored in AWS Secrets Manager"
}
