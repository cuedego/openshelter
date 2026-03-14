output "secret_arns" {
  description = "Map of secret key to ARN"
  value       = { for k, v in aws_secretsmanager_secret.this : k => v.arn }
}

output "secret_names" {
  description = "Map of secret key to full AWS secret name"
  value       = { for k, v in aws_secretsmanager_secret.this : k => v.name }
}
