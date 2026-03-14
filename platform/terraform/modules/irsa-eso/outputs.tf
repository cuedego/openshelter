output "role_arn" {
  description = "ARN of the ESO IRSA role — annotate the ESO service account with this value"
  value       = aws_iam_role.eso.arn
}

output "role_name" {
  value = aws_iam_role.eso.name
}
