output "role_arn" {
  description = "ARN of the IRSA role for the AWS Load Balancer Controller"
  value       = aws_iam_role.this.arn
}

output "role_name" {
  description = "Name of the IRSA role for the AWS Load Balancer Controller"
  value       = aws_iam_role.this.name
}
